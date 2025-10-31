# frozen_string_literal: true

require 'filter_spec_helper'
require 'spec_helper'

describe Submission do
  before do
    Survey.delete_all
    Answer.delete_all
    Question.delete_all
    described_class.delete_all
    PossibleAnswer.delete_all
    Device.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:udid2) { '00000000-0000-4000-f000-000000000002' }

  describe 'Before destroy' do
    it 'recalculates survey#answers_count' do
      survey = create(:survey)
      survey.survey_stat.update(answers_count: 2)
      question = create(:question, survey: survey)
      device = create(:device, udid: udid)
      device2 = create(:device, udid: udid2)

      submission = create(:submission, device_id: device.id, survey_id: survey.id, closed_by_user: true)
      submission2 = create(:submission, device_id: device2.id, survey_id: survey.id, closed_by_user: true)

      create(:answer, question_id: question.id, submission_id: submission.id, possible_answer_id: question.possible_answers.first.id)
      create(:answer, question_id: question.id, submission_id: submission2.id, possible_answer_id: question.possible_answers.first.id)

      survey.reload

      expect(survey.answers_count).to eq 2

      submission.destroy
      survey.reload

      expect(survey.answers_count).to eq 1

      submission2.destroy
      survey.reload

      expect(survey.answers_count).to eq 0
    end
  end

  describe 'After destroy' do
    def store_old_counts
      @old_impression_count = @cache_record.impression_count
      @old_submission_count = @cache_record.submission_count
      @old_viewed_impression_count = @cache_record.viewed_impression_count
    end

    describe "SurveySubmissionCache" do
      let(:survey) { create(:survey) }

      context "when there are no other submissions for the survey on the same day" do
        before do
          @submission = create(:submission, survey_id: survey.id)

          @cache_record = SurveySubmissionCache.recalculate(survey.id, @submission.created_at.to_date)
        end

        it "destroys the cache record" do
          @submission.destroy

          expect(SurveySubmissionCache.where(id: @cache_record.id).exists?).to be false
        end
      end

      context "when there are other submissions for the survey on the same day" do
        let!(:other_submission) { create(:submission, survey_id: survey.id, answers_count: 1) }

        context "when an impression" do
          let(:submission) { create(:submission, survey_id: survey.id) }

          before do
            @cache_record = SurveySubmissionCache.recalculate(survey.id, submission.created_at.to_date)

            store_old_counts

            submission.destroy
            @cache_record.reload
          end

          it "updates SurveySubmissionCache" do
            expect(@cache_record.impression_count).to eq @old_impression_count - 1
            expect(@cache_record.submission_count).to eq @old_submission_count
            expect(@cache_record.viewed_impression_count).to eq @old_viewed_impression_count
          end

          context "when the last impression" do
            let(:submission) { create(:submission, survey_id: survey.id, created_at: 1.minute.from_now) }

            it "updates last_impression_at" do
              expect(@cache_record.last_impression_at).to be_within(1.second).of other_submission.created_at
            end
          end

          context "when not the last impression" do
            let(:submission) { create(:submission, survey_id: survey.id, created_at: 1.minute.ago) }

            it "does not update last_impression_at" do
              expect(@cache_record.last_impression_at).to be_within(1.second).of other_submission.created_at
            end
          end
        end

        context "when a viewed impression" do
          let(:submission) { create(:submission, survey_id: survey.id, viewed_at: Time.current) }

          before do
            @cache_record = SurveySubmissionCache.recalculate(survey.id, submission.created_at.to_date)

            store_old_counts

            submission.destroy
            @cache_record.reload
          end

          it "updates SurveySubmissionCache" do
            expect(@cache_record.impression_count).to eq @old_impression_count - 1
            expect(@cache_record.submission_count).to eq @old_submission_count
            expect(@cache_record.viewed_impression_count).to eq @old_viewed_impression_count - 1
          end

          context "when the last impression" do
            let(:submission) { create(:submission, survey_id: survey.id, viewed_at: Time.current, created_at: 1.minute.from_now) }

            it "updates last_impression_at" do
              expect(@cache_record.last_impression_at).to be_within(1.second).of other_submission.created_at
            end
          end

          context "when not the last impression" do
            let(:submission) { create(:submission, survey_id: survey.id, viewed_at: Time.current, created_at: 1.minute.ago) }

            it "does not update last_impression_at" do
              expect(@cache_record.last_impression_at).to be_within(1.second).of other_submission.created_at
            end
          end
        end

        context "when a submission" do
          let(:submission) { create(:submission, survey_id: survey.id, viewed_at: Time.current, answers_count: 1) }

          before do
            @cache_record = SurveySubmissionCache.recalculate(survey.id, submission.created_at.to_date)

            store_old_counts

            submission.destroy
            @cache_record.reload
          end

          it "updates SurveySubmissionCache" do
            expect(@cache_record.impression_count).to eq @old_impression_count - 1
            expect(@cache_record.submission_count).to eq @old_submission_count - 1
            expect(@cache_record.viewed_impression_count).to eq @old_viewed_impression_count - 1
          end

          context "when the last impression" do
            let(:submission) { create(:submission, survey_id: survey.id, viewed_at: Time.current, answers_count: 1, created_at: 1.minute.from_now) }

            it "updates last_impression_at" do
              expect(@cache_record.last_impression_at).to be_within(1.second).of other_submission.created_at
            end
          end

          context "when not the last impression" do
            let(:submission) { create(:submission, survey_id: survey.id, viewed_at: Time.current, answers_count: 1, created_at: 1.minute.ago) }

            it "does not update last_impression_at" do
              expect(@cache_record.last_impression_at).to be_within(1.second).of other_submission.created_at
            end
          end

          context "when the last submission" do
            let(:submission) { create(:submission, survey_id: survey.id, viewed_at: Time.current, answers_count: 1, created_at: 1.minute.from_now) }

            it "updates last_submission_at" do
              expect(@cache_record.last_submission_at).to be_within(1.second).of other_submission.created_at
            end
          end

          context "when not the last submission" do
            let(:submission) { create(:submission, survey_id: survey.id, viewed_at: Time.current, answers_count: 1, created_at: 1.minute.ago) }

            it "does not update last_submission_at" do
              expect(@cache_record.last_submission_at).to be_within(1.second).of other_submission.created_at
            end
          end
        end
      end

      context "when there is no cache record for that day" do
        before do
          @submission = create(:submission, survey_id: survey.id)
        end

        it "doesn't break" do
          expect { @submission.destroy }.not_to raise_error
        end
      end
    end
  end

  it_behaves_like "filter sharing" do
    def make_records(filter_attribute = nil, attribute_value = nil)
      create(:submission) and return if filter_attribute.nil?

      case filter_attribute
      when :created_at, :device_type, :url, :pageview_count, :visit_count
        create(:submission, filter_attribute => attribute_value)
      when :possible_answer_id
        make_possible_answer_filter_records(create(:survey), attribute_value)
      else
        raise "Unrecognized data type #{filter_attribute}"
      end
    end

    def it_filters(filters)
      submission_scope = Submission.all

      filters.each do |field, value|
        submission_scope = case field
        when :date_range
          submission_scope.where(created_at: value)
        when :device_types
          submission_scope.where(device_type: value)
        when :market_ids
          submission_scope.where(survey_id: value)
        when :completion_urls
          submission_scope.where(CompletionUrlFilter.combined_sql(value))
        when :pageview_count, :visit_count
          submission_scope.where(value.to_sql)
        when :possible_answer_id
          submission_ids = Answer.where(possible_answer_id: value).pluck(:submission_id)
          submission_scope.where(id: submission_ids)
        else
          Rails.logger.info "Unrecognized filter #{field}"
          submission_scope
        end
      end

      expected_scope = Submission.filtered_submissions(Submission.all, filters: filters)

      expect(submission_scope.count).to eq(expected_scope.count)
      expect(submission_scope).to eq(expected_scope)
    end
  end

  describe "#find_with_retry_by!" do
    it 'finds a submission through a given attribute' do
      client_key = FFaker::Lorem.word
      submission = create(:submission, udid: udid, client_key: client_key)
      expect(described_class.find_with_retry_by!(udid: udid)).to eq submission
      expect(described_class.find_with_retry_by!(client_key: client_key)).to eq submission
    end

    it 'raises an error if no submission was found' do
      stub_const('Submission::FETCHING_INTERVAL', 1) # 5 seconds is too long for a single test case
      expect { described_class.find_with_retry_by!(udid: udid) }.to raise_error ActiveRecord::RecordNotFound
    end
  end
end
