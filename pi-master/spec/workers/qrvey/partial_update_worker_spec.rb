# frozen_string_literal: true
require 'spec_helper'

describe Qrvey::PartialUpdateWorker do
  let(:worker) { described_class.new }

  let(:unique_id_key) { :answer_id }

  let(:time_range) { (5.minutes.ago..5.minutes.after) } # the worker rounds seconds, meaning the latest audits get filtered out without this

  before do
    @survey = create(:survey, status: :draft) # with "live", "live_at" needs to be in the payload for each test
    @question = @survey.questions.first
    @possible_answer = @question.possible_answers.first

    @duplicate_survey = @survey.duplicate
    @duplicate_survey.save
    @survey.localize!
    @duplicate_survey.add_to_localization_group(@survey.survey_locale_group_id, 'en')

    # loading parent groups
    @survey.reload
    @question.reload
    @possible_answer.reload

    # creating answers
    @survey.survey_locale_group.surveys.each do |survey|
      survey.questions.each do |question|
        question.possible_answers.each do |possible_answer|
          10.times do
            submission = create(:submission, survey: survey)
            create(:answer, submission: submission, question: question, possible_answer: possible_answer)
          end
        end
      end
    end
  end

  describe "Audit filtering" do
    before do
      purge_audits

      new_thank_you = 'new thank you' # the update to send to Qrvey
      @survey.update(thank_you: new_thank_you)

      @updates = generate_updates(@survey.answers, { survey_thank_you: new_thank_you, survey_updated: @survey.reload.updated_at })
    end

    it "filters out types other than 'update'" do
      create(:answer) # creating an audit of irrelevant types

      expect(worker).to receive(:send_to_push_api).with(@updates)
      worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
    end

    it "filters out audits outside of a time range" do
      # directly creating an audit not to change the survey's updated_at which is used in the payload
      @survey.audits.create(auditable: @survey, audited_changes: {}, created_at: time_range.last + 5.minutes)

      expect(worker).to receive(:send_to_push_api).with(@updates)
      worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
    end

    it "filters out non-metadata tables" do
      create(:user) # creating an audit for an irrelevant table

      expect(worker).to receive(:send_to_push_api).with(@updates)
      worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
    end
  end

  describe "Common fields" do
    before do
      purge_audits
    end

    it 'removes irrelevant keys, translates keys, and reflects the latest values' do
      new_thank_you = 'new thank you'
      @survey.update(thank_you: new_thank_you, width: rand(1000))
      updates = generate_updates(@survey.answers, { survey_thank_you: new_thank_you, survey_updated: @survey.reload.updated_at })

      expect(worker).to receive(:send_to_push_api).with(updates)
      worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
    end

    it 'handles single table inheritance' do
      new_name = FFaker::Lorem.word
      question_locale_group = @question.question_locale_group
      question_locale_group.update(name: new_name)

      fields_to_update = { question_canonical: new_name, question_canonical_updated: question_locale_group.reload.updated_at }
      updates = generate_updates(question_locale_group.answers, fields_to_update)
      expect(worker).to receive(:send_to_push_api).with(updates)
      worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
    end

    it "handles free text question's next question" do
      free_text_question = create(:free_text_question, survey: @survey)
      10.times { create(:answer, question: free_text_question, text_answer: FFaker::Lorem.name) }

      new_next_question_id = @question.id
      free_text_question.update(free_text_next_question_id: new_next_question_id)

      fields_to_update = { next_question_id: new_next_question_id, question_updated: free_text_question.reload.updated_at }
      updates = generate_updates(free_text_question.answers, fields_to_update)
      expect(worker).to receive(:send_to_push_api).with(updates)
      worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
    end

    describe 'additional fields' do
      context 'with surveys' do
        it 'returns additional fields for status and survey_type' do
          new_status = 'paused'
          new_survey_type = 'inline'
          @survey.update(status: new_status, survey_type: new_survey_type)

          fields_to_update = {
            survey_status_id: Survey.statuses[new_status], # Additional field
            survey_type_id: Survey.survey_types[new_survey_type], # Additional field
            survey_status: new_status,
            survey_type: new_survey_type,
            survey_updated: @survey.reload.updated_at
          }

          updates = generate_updates(@survey.answers, fields_to_update)
          expect(worker).to receive(:send_to_push_api).with(updates)
          worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
        end
      end
    end
  end

  describe "Special fields" do
    before do
      allow(worker).to receive(:update_common_fields) # Preventing multiple invocations of "send_to_push_api"
    end

    describe "next_question field" do
      before do
        allow(worker).to receive(:update_next_question_base_field)
        allow(worker).to receive(:update_question_base_field)
      end

      it "builds an intended payload" do
        next_question = (@survey.questions - [@question]).sample
        @question.update(next_question_id: next_question.id)

        purge_audits

        new_content = 'new content'
        next_question.update(content: new_content)

        updates = generate_updates(@question.answers, { next_question: new_content })
        expect(worker).to receive(:send_to_push_api).with(updates)
        worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
      end
    end

    describe 'next_question_base field' do
      before do
        # Preventing multiple invocations of "send_to_push_api"
        allow(worker).to receive(:update_next_question_field)
        allow(worker).to receive(:update_question_base_field)
      end

      it "builds an intended payload" do
        non_base_question = @duplicate_survey.reload.questions.first
        question_locale_group = non_base_question.question_locale_group
        base_question = question_locale_group.base_question

        # Creating "previous" questions that a change to the next question affects
        other_question_group = @survey.survey_locale_group.question_locale_groups.last
        other_question_group.questions.each { |question| question.update(next_question_id: base_question.id) }

        purge_audits

        base_question.update(content: FFaker::Lorem.word)

        updates = generate_updates(other_question_group.answers, { next_question_base: base_question.content })
        expect(worker).to receive(:send_to_push_api).with(updates)
        worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
      end
    end

    describe 'survey_base field' do
      it 'builds an intended payload' do
        new_survey_name = FFaker::Lorem.word
        @survey.update(name: new_survey_name)

        localized_surveys = @survey.survey_locale_group.surveys
        updates = generate_updates(Answer.joins(:submission).where(submission: { survey: localized_surveys }), { survey_base: new_survey_name })
        expect(worker).to receive(:send_to_push_api).with(updates)
        worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
      end
    end

    describe 'question_base field' do
      before do
        # Preventing multiple invocations of "send_to_push_api"
        allow(worker).to receive(:update_next_question_field)
        allow(worker).to receive(:update_next_question_base_field)
      end

      it 'has an intended payload' do
        purge_audits

        new_question_content = 'new question content'
        @question.update(content: new_question_content)

        updates = generate_updates(Answer.where(question: @question.question_locale_group.questions), { question_base: new_question_content })
        expect(worker).to receive(:send_to_push_api).with(updates)
        worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
      end
    end

    describe 'response_base field' do
      it 'builds an intended payload' do
        purge_audits

        new_possible_answer_content = 'new possible answer content'
        @possible_answer.update(content: new_possible_answer_content)

        localized_possible_answers = @possible_answer.possible_answer_locale_group.possible_answers
        updates = generate_updates(Answer.where(possible_answer: localized_possible_answers), { response_base: new_possible_answer_content })
        expect(worker).to receive(:send_to_push_api).with(updates)
        worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
      end
    end

    describe 'next question fields for multiple choices questions' do
      let(:multiple_choice_question) { create(:multiple_choices_question, survey: @survey) }
      let(:next_question) { @question }
      let(:next_question_locale_group) { next_question.question_locale_group }

      let(:fields_to_update) do
        {
          next_question_id: next_question.id,
          next_question_id_canonical: next_question_locale_group.id,
          next_question_canonical: next_question_locale_group.name,
          next_question_base: next_question_locale_group.base_question.content
        }
      end

      before do
        10.times { create(:answer, question: multiple_choice_question, possible_answer: multiple_choice_question.possible_answers.sample) }
      end

      context 'when the last possible answer has a next question' do
        it 'filters out the last possible answer from a payload' do
          last_possible_answer = multiple_choice_question.possible_answers.sort_by_position.last
          last_possible_answer.update(next_question_id: next_question.id)

          purge_audits

          multiple_choice_question.update(next_question_id: next_question.id)

          updates = generate_updates(multiple_choice_question.answers.where.not(possible_answer: last_possible_answer), fields_to_update)
          expect(worker).to receive(:send_to_push_api).with(updates)
          worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
        end
      end

      context "when the last possible answer doesn't have a next question" do
        it 'includes all answers to the question in a payload' do
          purge_audits

          multiple_choice_question.update(next_question_id: next_question.id)

          updates = generate_updates(multiple_choice_question.answers, fields_to_update)
          expect(worker).to receive(:send_to_push_api).with(updates)
          worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
        end
      end

      context 'when the next question has been removed' do
        before do
          # Setting next_question_id to something so an audit record is generated when updating the column with nil below
          multiple_choice_question.update(next_question_id: rand(10))

          purge_audits

          multiple_choice_question.update(next_question_id: nil)
        end

        it 'updates the field with nil' do
          updates = generate_updates(multiple_choice_question.answers, { next_question_id: nil })
          expect(worker).to receive(:send_to_push_api).with(updates)
          worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
        end
      end
    end

    describe "tags field" do
      before do
        purge_audits

        # applied_tags that just have been applied
        @survey.questions.first.answers.each { |answer| create(:applied_tag, answer: answer) }

        # applied_tags that had been applied a long ago, but the tag name has changed just now
        @tag = create(:tag, question: @question)
        @survey.questions.last.answers.each do |answer|
          create(:applied_tag, answer: answer, tag: @tag, created_at: time_range.first - 5.minutes)
        end
        @tag.update(name: FFaker::Lorem.name)
      end

      it 'builds a payload made of recently created tags and recently modified tags' do
        updates = Answer.includes(:tags).where(question: @survey.questions).order(:id).map do |answer|
          { unique_id_key => answer.id, tags: answer.tags.order(:id).pluck(:name).join('; ') }
        end
        expect(worker).to receive(:send_to_push_api).with(updates)
        worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
      end

      it 'builds a payload considering removed applied_tags and deleted tags' do
        # Deleted tag(the associated applied_tags are also deleted along the way)
        @tag.destroy
        # Untagged tags
        AppliedTag.where(answer: @question.answers).destroy_all # #delete won't trigger audit generation

        updates = Answer.includes(:tags).where(question: @survey.questions).order(:id).map do |answer|
          { unique_id_key => answer.id, tags: answer.tags.order(:id).pluck(:name).join('; ') }
        end
        expect(worker).to receive(:send_to_push_api).with(updates)
        worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
      end
    end

    describe "survey_tags field" do
      let(:survey_tag) { create(:survey_tag, account: @survey.account) }
      let(:survey_tag2) { create(:survey_tag, account: @survey.account) }

      before do
        purge_audits
      end

      context 'with applied_survey_tags' do
        before do
          create(:applied_survey_tag, survey_tag: survey_tag, survey: @survey)
          create(:applied_survey_tag, survey_tag: survey_tag2, survey: @survey)
        end

        context 'when tags have been applied' do
          it 'builds a payload off them' do
            updates = generate_updates(@survey.answers, { survey_tags: "#{survey_tag.name}; #{survey_tag2.name}" })
            expect(worker).to receive(:send_to_push_api).with(updates)
            worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
          end
        end

        context 'when tags have been removed' do
          it 'builds a payload considering the removals' do
            survey_tag2.applied_survey_tags.destroy_all
            updates = generate_updates(@survey.answers, { survey_tags: survey_tag.name })
            expect(worker).to receive(:send_to_push_api).with(updates)
            worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
          end
        end
      end

      context 'with survey_tags' do
        before do
          # Tags have been applied before the start_time, but their names have changed just now
          survey_tag.update(name: FFaker::Lorem.unique.word)
          survey_tag2.update(name: FFaker::Lorem.unique.word)
          create(:applied_survey_tag, survey_tag: survey_tag, survey: @survey, created_at: time_range.first - 5.minutes)
          create(:applied_survey_tag, survey_tag: survey_tag2, survey: @survey, created_at: time_range.first - 5.minutes)
        end

        context 'when tags have had their name changed' do
          it 'builds a payload off them' do
            updates = generate_updates(@survey.answers, { survey_tags: "#{survey_tag.name}; #{survey_tag2.name}" })
            expect(worker).to receive(:send_to_push_api).with(updates)
            worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
          end
        end

        context 'when tags have been deleted' do
          it 'builds a payload considering the deletion' do
            survey_tag2.destroy
            updates = generate_updates(@survey.answers, { survey_tags: survey_tag.name })
            expect(worker).to receive(:send_to_push_api).with(updates)
            worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
          end
        end
      end

      describe 'staging tags' do
        it 'fills "survey_tag_staging" field if one of the survey tags includes "staging"' do
          survey_tag.update(name: 'staging test')
          create(:applied_survey_tag, survey_tag: survey_tag, survey: @survey)

          updates = generate_updates(@survey.answers, { survey_tags: survey_tag.name, survey_tag_staging: 'staging' })
          expect(worker).to receive(:send_to_push_api).with(updates)
          worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
        end
      end
    end

    describe '#update_sort_id_field_for_question' do
      it 'contains in the payload "sort_id" & "sort_group_id" built off of a newly changed position' do
        free_text_question = create(:free_text_question, survey: @survey)
        10.times do
          submission = create(:submission, survey: @survey)
          create(:answer, submission: submission, question: free_text_question, text_answer: FFaker::Lorem.sentence)
        end

        purge_audits

        new_question_position = rand(@survey.questions.count...10)
        free_text_question.update(position: new_question_position)

        sort_id = "#{@survey.id}.00#{new_question_position}000"
        sort_group_id = "#{@survey.survey_locale_group_id}.00#{new_question_position}000"
        updates = generate_updates(free_text_question.answers, { sort_id: sort_id, sort_group_id: sort_group_id })
        expect(worker).to receive(:send_to_push_api).with(updates)
        worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
      end
    end

    describe '#update_sort_id_field_for_possible_answer' do
      it 'has the correct payload' do
        purge_audits

        new_possible_answer_position = rand(@question.possible_answers.count...10)
        @possible_answer.update(position: new_possible_answer_position)

        sort_id = "#{@survey.id}.00#{@question.position}00#{new_possible_answer_position}"
        sort_group_id = "#{@survey.survey_locale_group_id}.00#{@question.position}00#{new_possible_answer_position}"
        updates = generate_updates(@possible_answer.answers, { sort_id: sort_id, sort_group_id: sort_group_id })
        expect(worker).to receive(:send_to_push_api).with(updates)
        worker.perform(custom_start_time: time_range.first, custom_end_time: time_range.last)
      end
    end
  end

  def generate_updates(answers, fields)
    answers.order(:id).map { |answer| { unique_id_key => answer.id }.merge fields }.flatten
  end

  def purge_audits
    CustomAudit.destroy_all
  end
end
