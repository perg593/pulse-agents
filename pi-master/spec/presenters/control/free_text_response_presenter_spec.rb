# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'

require "dry-types"

TagSchema = Dry::Schema.JSON do
  required(:id).value(:integer)
  required(:text).value(:string)
  required(:color).value(:string)
end

TextResponseRowSchema = Dry::Schema.JSON do
  required(:id).value(:integer)
  required(:createdAt).value(:string)
  required(:appliedTags).value(Dry.Types::Array.of(FreeTextResponseAppliedTagSchema))
  required(:translation).maybe(:string)
  required(:completionUrl).maybe(:string)
  required(:sentiment).maybe(:string)
  required(:customData).maybe(:string) # json
  required(:deviceType).maybe(:string) # enum?
  required(:deviceData).maybe(:string)
  required(:textResponse).value(:string)
end

PropsSchema = Dry::Schema.JSON do
  required(:autotagEnabled).value(:bool)
  required(:question).value(:hash) do
    required(:id).value(:integer)
    required(:content).value(:string)
    required(:autotagEnabled).value(:bool)
  end
  required(:tagOptions).value(Dry.Types::Array.of(TagSchema))
  required(:tableData).value(Dry.Types::Array.of(TextResponseRowSchema))
  required(:surveyId).value(:integer)
end

describe Control::FreeTextResponsePresenter do
  let(:account) { create(:account) }
  let(:survey) { create(:survey_without_question, account: account) }
  let(:free_text_question) { create(:free_text_question, survey: survey) }

  describe "props" do
    let(:presenter) { described_class.new(free_text_question) }
    let(:props) { presenter.props }

    it "returns a valid schema" do
      assert_valid_schema PropsSchema, props
    end

    describe "autotagEnabled" do
      subject { props["autotagEnabled"] }

      context "when the account has autotag enabled" do
        let(:presenter) { described_class.new(free_text_question, autotag_enabled: true) }

        it { is_expected.to be true }
      end

      context "when the account does not have autotag enabled" do
        it { is_expected.to be false }
      end
    end

    describe "question" do
      it "returns question content" do
        question_props = props["question"]

        expect(question_props["content"]).to eq free_text_question.content
        expect(question_props["id"]).to eq free_text_question.id
      end

      context "when the question has autotag enabled" do
        before do
          free_text_question.update(tag_automation_worker_enabled: true)
        end

        it "returns a valid schema" do
          assert_valid_schema PropsSchema, props
        end

        it "returns true" do
          question_props = props["question"]

          expect(question_props["autotagEnabled"]).to be true
        end
      end

      context "when the question does not have autotag enabled" do
        before do
          free_text_question.update(tag_automation_worker_enabled: false)
        end

        it "returns a valid schema" do
          assert_valid_schema PropsSchema, props
        end

        it "returns false" do
          question_props = props["question"]

          expect(question_props["autotagEnabled"]).to be false
        end
      end
    end

    describe "tagOptions" do
      context "when the question has no tags" do
        it "returns a valid schema" do
          assert_valid_schema PropsSchema, props
        end

        it "returns no tag options" do
          tag_props = props["tagOptions"]

          expect(tag_props.count).to eq 0
        end
      end

      context "when the question has tags" do
        before do
          3.times { create(:tag, question: free_text_question) }
        end

        it "returns a valid schema" do
          assert_valid_schema PropsSchema, props
        end

        it "returns tag options" do
          tag_props = props["tagOptions"]

          expect(tag_props.count).to eq free_text_question.tags.count

          free_text_question.tags.order(:name).each_with_index do |tag, tag_index|
            tag_prop = tag_props[tag_index]

            expect(tag_prop["id"]).to eq tag.id
            expect(tag_prop["text"]).to eq tag.name
          end
        end

        context "when a tag is a placeholder" do
          before do
            @placeholder_tag = create(:tag, question: free_text_question, name: Tag::AUTOMATION_PLACEHOLDER_NAME)
          end

          it "does not return the placeholder" do
            tag_props = props["tagOptions"]

            expect(tag_props.pluck("id")).not_to include(@placeholder_tag.id)
            expect(tag_props.pluck("text")).not_to include(Tag::AUTOMATION_PLACEHOLDER_NAME)
          end
        end
      end
    end

    describe "surveyId" do
      it "returns the question's survey's ID" do
        survey_id = props["surveyId"]

        expect(survey_id).to eq free_text_question.survey.id
      end
    end

    describe "text_response_table_data" do
      context "when there are no answers" do
        it "returns a valid schema" do
          assert_valid_schema PropsSchema, props
        end
      end

      it_behaves_like "filter sharing" do
        def make_answer(submission_extras: {}, answer_extras: {})
          submission = create(:submission, **submission_extras)
          create(:free_text_answer, submission: submission, question: free_text_question, **answer_extras)
        end

        def make_records(filter_attribute = nil, attribute_value = nil)
          make_answer and return if filter_attribute.nil?

          case filter_attribute
          when :created_at
            make_answer(answer_extras: { created_at: attribute_value }, submission_extras: { created_at: attribute_value })
          when :device_type, :url, :pageview_count, :visit_count
            make_answer(submission_extras: { filter_attribute => attribute_value })
          when :possible_answer_id
            create(:question, survey: survey)
            create(:question, survey: survey)
            survey.reload
            target_submission = make_possible_answer_filter_records(survey, attribute_value)
            create(:free_text_answer, submission: target_submission, question: free_text_question)
          else
            raise "Unrecognized data type #{filter_attribute}"
          end
        end

        def it_filters(filters)
          filtered_answers = Answer.filtered_answers(free_text_question.answers, filters: filters)
          filtered_answers = filtered_answers.where(question_type: :free_text_question)
          row_data = described_class.new(free_text_question, filters: filters).props["tableData"]

          expect(row_data.count).to eq(filtered_answers.count)
          expect(filtered_answers.pluck(:id).sort).to eq(row_data.map { |row| row["id"] }.sort)
        end
      end

      context "when there are answers" do
        before do
          3.times do
            submission = create(:submission, survey: survey)
            create(:free_text_answer, question: free_text_question, submission: submission)
          end
        end

        it "returns a valid schema" do
          assert_valid_schema PropsSchema, props
        end

        it "returns table data" do
          table_data_props = props["tableData"]

          free_text_question.answers.order(:id).each_with_index do |answer, answer_index|
            answer_props = table_data_props[answer_index]

            expect(answer_props["id"]).to eq answer.id
            expect(answer_props["textResponse"]).to eq answer.text_answer
            expect(answer_props["createdAt"]).to eq answer.created_at.strftime("%m/%d/%Y %X")
          end
        end

        context "when the submissions have urls" do
          before do
            free_text_question.answers.order(:id).each do |answer|
              answer.submission.update(url: FFaker::Internet.http_url)
            end
          end

          it "returns a valid schema" do
            assert_valid_schema PropsSchema, props
          end

          it "returns the completion url" do
            table_data_props = props["tableData"]

            free_text_question.answers.order(:id).each_with_index do |answer, answer_index|
              answer_props = table_data_props[answer_index]

              expect(answer_props["completionUrl"]).to eq answer.submission.url
            end
          end
        end

        context "when the answers have translations" do
          before do
            free_text_question.answers.order(:id).each do |answer|
              answer.update(translated_answer: FFaker::Lorem.phrase)
            end
          end

          it "returns a valid schema" do
            assert_valid_schema PropsSchema, props
          end

          it "returns the translation" do
            table_data_props = props["tableData"]

            free_text_question.answers.order(:id).each_with_index do |answer, answer_index|
              answer_props = table_data_props[answer_index]

              expect(answer_props["translation"]).to eq answer.translated_answer
            end
          end
        end

        context "when the answers have tags applied" do
          before do
            free_text_question.answers.order(:id).each do |answer|
              create(:applied_tag, answer: answer)
              create(:applied_tag, answer: answer)
              create(:automatically_applied_tag, answer: answer)
              create(:automatically_applied_tag, answer: answer, is_good_automation: true)
              create(:automatically_applied_tag, answer: answer, is_good_automation: true, tag: create(:tag, name: Tag::AUTOMATION_PLACEHOLDER_NAME))
            end
          end

          it "returns a valid schema" do
            assert_valid_schema PropsSchema, props
          end

          it "returns the applied tags" do
            table_data_props = props["tableData"]

            free_text_question.answers.order(:id).each_with_index do |answer, answer_index|
              answer_props = table_data_props[answer_index]

              applied_tag_scope = answer.applied_tags.joins(:tag).where.not(tags: { name: Tag::AUTOMATION_PLACEHOLDER_NAME })

              expect(answer_props["appliedTags"].count).to eq applied_tag_scope.count

              applied_tag_scope.order("tags.name").each_with_index do |applied_tag, applied_tag_index|
                applied_tag_props = answer_props["appliedTags"][applied_tag_index]

                expect(applied_tag_props["appliedTagId"]).to eq applied_tag.id
                expect(applied_tag_props["tagId"]).to eq applied_tag.tag_id
                expect(applied_tag_props["text"]).to eq applied_tag.tag.name
                expect(applied_tag_props["tagApproved"]).to eq applied_tag.approved?
                expect(applied_tag_props["tagColor"]).to eq applied_tag.tag.color
              end
            end
          end
        end

        context "when the answers have sentiment calculated" do
          before do
            free_text_question.answers.order(:id).each do |answer|
              answer.update(sentiment: {"score" => 0.5, "magnitude" => 0.5})
            end
          end

          it "returns a valid schema" do
            assert_valid_schema PropsSchema, props
          end

          it "returns the sentiment" do
            table_data_props = props["tableData"]

            free_text_question.answers.order(:id).each_with_index do |answer, answer_index|
              answer_props = table_data_props[answer_index]

              expect(answer_props["sentiment"]).to eq answer.human_friendly_sentiment
            end
          end
        end

        context "when the answers have custom data" do
          before do
            free_text_question.answers.order(:id).each do |answer|
              answer.submission.update(custom_data: { "alpha" => "beta" })
            end
          end

          it "returns a valid schema" do
            assert_valid_schema PropsSchema, props
          end

          it "returns the custom data" do
            table_data_props = props["tableData"]

            free_text_question.answers.order(:id).each_with_index do |answer, answer_index|
              answer_props = table_data_props[answer_index]

              expect(JSON.parse(answer_props["customData"])).to eq answer.submission.custom_data
            end
          end
        end

        context "when the answers have device data" do
          before do
            free_text_question.answers.order(:id).each do |answer|
              data = [{ "device" => "data" }]
              create(:device_data, device_id: answer.submission.device_id, device_data: data, account_id: free_text_question.survey.account_id)
              create(:device_data, device_id: answer.submission.device_id, device_data: data, account_id: free_text_question.survey.account_id)
            end
          end

          it "returns a valid schema" do
            assert_valid_schema PropsSchema, props
          end

          it "returns the device data" do
            table_data_props = props["tableData"]

            free_text_question.answers.order(:id).each_with_index do |answer, answer_index|
              answer_props = table_data_props[answer_index]

              expected_data = answer.submission.device.device_datas.map(&:device_data)

              expect(JSON.parse(answer_props["deviceData"])).to eq expected_data
            end
          end
        end

        context "when the answers have device type" do
          before do
            free_text_question.answers.order(:id).each do |answer|
              answer.submission.update(device_type: "desktop")
            end
          end

          it "returns a valid schema" do
            assert_valid_schema PropsSchema, props
          end

          it "returns the device type" do
            table_data_props = props["tableData"]

            free_text_question.answers.order(:id).each_with_index do |answer, answer_index|
              answer_props = table_data_props[answer_index]

              expect(answer_props["deviceType"]).to eq answer.submission.device_type
            end
          end
        end
      end
    end
  end
end
