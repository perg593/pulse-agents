# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "survey_questions_schema")

describe Rack::SurveyQuestions do
  before do
    Account.delete_all
    Survey.delete_all
    Trigger.delete_all
    Question.delete_all
    PossibleAnswer.delete_all
    Device.delete_all
    Submission.delete_all
    Answer.delete_all
    DeviceData.delete_all
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

  # rubocop:disable RSpec/ExampleLength
  # There are many fields worth verifying
  describe '/surveys/:id/questions' do
    it_behaves_like "account verifier" do
      def make_call(identifier_param)
        survey = create(:survey, account: create(:account))

        url = "/surveys/#{survey.id}/questions?callback=#{callback}#{identifier_param}"

        headers = { Referer: "http://localhost:3000" }

        rack_app(url, headers)
      end
    end

    it_behaves_like "disabled account verifier" do
      def make_call(account)
        survey = create(:survey, account: account)

        url = "/surveys/#{survey.id}/questions?callback=#{callback}&identifier=#{account.identifier}"

        headers = { Referer: "http://localhost:3000" }

        rack_app(url, headers)
      end
    end

    it_behaves_like "accounts.ips_to_block-based request blocker" do
      def make_call(preview_mode)
        survey = create(:survey, account: account)

        headers = { X_REAL_IP: "192.168.0.1" }

        query = {
          identifier: account.identifier,
          callback: callback,
          preview_mode: preview_mode
        }.to_query

        url = "/surveys/#{survey.id}/questions?#{query}"

        rack_app(url, headers)
      end

      def non_blocked_response(response)
        expect(response.code).to eq "200"
        assert_valid_schema RackSchemas::SurveyQuestions::SuccessfulResponseSchema, parse_json_response(response.body)
      end
    end

    describe "response validation" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account) }

      before do
        Question.question_types.keys.map(&:to_sym).each do |question_type|
          create(question_type, survey: survey)
        end

        @response = rack_app(url)
      end

      context "when successful" do
        let(:url) { "/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}" }

        it "returns code 200" do
          expect(@response.code).to eq "200"
        end

        it "returns the expected schema" do
          json_response = parse_json_response(@response.body)
          assert_valid_schema RackSchemas::SurveyQuestions::SuccessfulResponseSchema, json_response

          json_response.each do |question|
            case question["question_type"]
            when "free_text_question"
              assert_valid_schema RackSchemas::Common::FreeTextQuestionSchema, question
            when "custom_content_question"
              assert_valid_schema RackSchemas::Common::CustomContentQuestionSchema, question
            when "multiple_choices_question"
              assert_valid_schema RackSchemas::Common::MultipleChoiceQuestionSchema, question
            when "slider_question"
              assert_valid_schema RackSchemas::Common::SliderQuestionSchema, question
            end
          end
        end
      end

      context "when unsuccessful" do
        let(:url) { "/surveys/#{survey.id}/questions?callback=#{callback}" }

        it "returns code 400" do
          expect(@response.code).to eq "400"
        end

        it "returns the expected schema" do
          assert_valid_schema RackSchemas::SurveyQuestions::ErrorResponseSchema, @response.body
        end
      end
    end

    it_behaves_like "rack parameter verifier", [:identifier], "/surveys/42/questions"

    describe 'params validation' do
      it "returns a 400 error if there's no identifier" do
        account = create(:account)
        survey = create(:survey)
        survey.account = account
        survey.save

        expect(rack_app("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}").code).to eq('200')
        expect(rack_app("/surveys/#{survey.id}/questions?callback=#{callback}").code).to eq('400')
      end
    end

    describe 'Question order' do
      it 'returns questions in the order of position' do
        survey = create(:survey)
        account = survey.reload.account
        3.times { create(:question, survey: survey) }

        positions = [13, 22, 40, 76, 99].shuffle # Popping this array instead of using rand() to avoid inserting a repetitive position number
        survey.questions.each { |question| question.update(position: positions.pop) }

        json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

        Question.where(survey: survey).sort_by_position.each_with_index do |question, index|
          expect(json_response[index]['id']).to eq question.id
        end
      end
    end

    describe 'Possible Answer ordering' do
      it 'returns possible answers in the order of position' do
        survey = create(:survey)
        account = survey.reload.account
        question = survey.questions.first

        survey.questions.where.not(id: question.id).destroy_all
        expect(survey.questions.count).to eq 1

        question.possible_answers.destroy_all
        positions = [13, 22, 40, 76, 99].shuffle # Not using rand() to avoid inserting a repetitive position number
        5.times { create(:possible_answer, question: question, position: positions.pop) }

        json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

        question.possible_answers.sort_by_position.each_with_index do |possible_answer, index|
          expect(json_response.first['possible_answers'][index]['id']).to eq possible_answer.id
        end
      end

      context 'when randomized order is enabled except for the last one' do
        it 'returns possible answers in a random order with the last question fixed at the end' do
          survey = create(:survey)
          account = survey.reload.account
          question = survey.questions.first

          survey.questions.where.not(id: question.id).destroy_all
          expect(survey.questions.count).to eq 1

          question.possible_answers.destroy_all
          5.times { |n| create(:possible_answer, question: question, position: n) }

          json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

          expect(json_response.first['possible_answers'].last['id']).to eq question.possible_answers.sort_by_position.last.id
        end
      end
    end

    it 'returns the questions and possible answers of the survey' do
      account = create(:account)
      survey = create(:survey)
      survey.account = account
      survey.save
      survey.reload

      json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

      common_question_keys = %w(
        id question_type position content submit_label
        button_type desktop_width_type answers_alignment_desktop answers_per_row_desktop
        answers_per_row_mobile optional image_type mobile_width_type
        answers_alignment_mobile created_at before_question_text after_question_text
        before_answers_count after_answers_count before_answers_items
        after_answers_items nps possible_answers single_choice_default_label
      )

      assert_valid_schema RackSchemas::SurveyQuestions::SuccessfulResponseSchema, json_response

      json_response.each do |question|
        expect(question.is_a?(Hash)).to be true
        expect(question.keys).to include(*common_question_keys)
      end

      expect(json_response.size).to eq(survey.questions.count)

      json_response.each_with_index do |question, index|
        expect(question["id"]).to eq(survey.questions[index].id)
      end
    end

    it 'returns the right params for a custom content question' do
      account = create(:account)
      survey = create(:survey)
      survey.account = account
      survey.save
      survey.reload

      custom_question = create(:custom_content_question, survey: survey)

      survey.reload

      json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

      expect(json_response.size).to eq(3)
      question = json_response.last

      expect(question["id"]).to eq(custom_question.id)
      expect(question["content"]).to eq(custom_question.custom_content) # the real 'content' for a custom content question is the 'custom content' field
    end

    it 'returns the right params for a localized question' do
      account = create(:account)
      survey = create(:survey)
      survey.account = account
      survey.save
      survey.reload
      survey.localize!

      json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

      survey.questions.each_with_index do |question, question_index|
        response_question = json_response[question_index]
        expect(response_question["question_locale_group_id"].to_i).to eq(question.question_locale_group_id)

        question.possible_answers.each_with_index do |possible_answer, possible_answer_index|
          response_possible_answer = json_response[question_index]["possible_answers"][possible_answer_index]
          expect(response_possible_answer["possible_answer_locale_group_id"].to_i).to eq(possible_answer.possible_answer_locale_group_id)
        end
      end
    end

    describe "additional_content" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account) }
      let(:additional_content) { FFaker::Lorem.phrase }
      let(:additional_content_position) { 1 }
      let(:show_additional_content) { nil }

      before do
        survey.questions.first.update(
          show_additional_content: show_additional_content,
          additional_content: additional_content,
          additional_content_position: additional_content_position
        )

        json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

        @question = json_response.first
      end

      context "when enabled" do
        let(:show_additional_content) { true }

        it "is returned" do
          expect(@question.keys).not_to include "show_additional_content"
          expect(@question["additional_content"]).to eq(additional_content)
          expect(@question["additional_content_position"]).to eq(additional_content_position)
        end
      end

      context "when not enabled" do
        let(:show_additional_content) { false }

        it "is not returned" do
          expect(@question.keys).not_to include "show_additional_content"
          expect(@question.keys).not_to include "additional_content"
          expect(@question.keys).not_to include "additional_content_position"
        end
      end
    end

    it 'returns the right params for a single choice question' do
      account = create(:account)
      survey = create(:survey, account: account)
      survey.reload

      answer_image_file = Rack::Test::UploadedFile.new("#{Rails.root}/spec/file_fixtures/background.jpg", "image/jpeg")

      answer_with_image = survey.questions.first.possible_answers.first

      answer_with_image.answer_image = AnswerImage.create(image: answer_image_file, imageable: account)
      answer_with_image.image_alt = "a picture I saw in a dream"
      answer_with_image.image_height = "256"
      answer_with_image.image_width = "128"
      answer_with_image.image_width_tablet = "64"
      answer_with_image.image_height_tablet = "32"
      answer_with_image.image_width_mobile = "16"
      answer_with_image.image_height_mobile = "8"
      answer_with_image.image_position_cd = PossibleAnswer.image_position_cds.values.last
      answer_with_image.save

      json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

      question = json_response.first

      expect(question["id"]).to eq(survey.questions.first.id)
      expect(question["content"]).to eq(survey.questions.first.content)

      expected_possible_answers_keys = %w(id position content next_question_id image_url image_alt image_width image_height image_width_mobile image_height_mobile image_width_tablet image_height_tablet image_position possible_answer_locale_group_id)

      question["possible_answers"].each do |possible_answer|
        expect(possible_answer.keys).to match_array(expected_possible_answers_keys)
      end

      expect(question["possible_answers"].size).to eq(2)
      expect(question["possible_answers"].map { |pa| pa["content"] }).to include(survey.questions.first.possible_answers[0].content)
      expect(question["possible_answers"].map { |pa| pa["content"] }).to include(survey.questions.first.possible_answers[1].content)

      expect(question["possible_answers"].first["image_url"]).to include(answer_with_image.answer_image_id.to_s)
      expect(question["possible_answers"].first["image_url"]).to include(answer_with_image.answer_image.image.file.filename)
      expect(question["possible_answers"].first["next_question_id"]).to eq(answer_with_image.next_question_id)

      expect(question["possible_answers"].first["position"]).to eq(answer_with_image.position)
      expect(question["possible_answers"].first["content"]).to eq(answer_with_image.content)
      expect(question["possible_answers"].first["image_alt"]).to eq(answer_with_image.image_alt)
      expect(question["possible_answers"].first["image_width"]).to eq(answer_with_image.image_width)
      expect(question["possible_answers"].first["image_height"]).to eq(answer_with_image.image_height)
      expect(question["possible_answers"].first["image_width_tablet"]).to eq(answer_with_image.image_width_tablet)
      expect(question["possible_answers"].first["image_height_tablet"]).to eq(answer_with_image.image_height_tablet)
      expect(question["possible_answers"].first["image_width_mobile"]).to eq(answer_with_image.image_width_mobile)
      expect(question["possible_answers"].first["image_height_mobile"]).to eq(answer_with_image.image_height_mobile)
      expect(question["possible_answers"].first["image_position"]).to eq(answer_with_image.read_attribute_before_type_cast(:image_position_cd).to_s)
    end

    it 'returns the right params for a multiple choices question' do
      account = create(:account)
      survey = create(:survey)
      survey.account = account
      survey.save
      survey.reload

      multiple_choices_question = create(
        :multiple_choices_question,
        survey: survey,
        enable_maximum_selection: true,
        maximum_selection: 1,
        next_question_id: 1,
        maximum_selections_exceeded_error_text: "too many selections"
      )

      survey.reload

      json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

      expect(json_response.size).to eq(3)
      question = json_response.last
      expect(question['next_question_id']).to eq multiple_choices_question.next_question_id
      expect(question['maximum_selection']).to eq multiple_choices_question.maximum_selection
      expect(question['maximum_selections_exceeded_error_text']).to eq multiple_choices_question.maximum_selections_exceeded_error_text
    end

    it 'returns the right params for a slider question' do
      account = create(:account)
      survey = create(:survey_without_question, account: account)
      slider_question = create(:slider_question, survey: survey)
      slider_possible_answers = slider_question.possible_answers.sort_by_position
      json_response = rack_app_as_json("/surveys/#{survey.id}/questions?identifier=#{account.identifier}&callback=#{callback}")

      question = json_response.first
      expect(question['id']).to eq slider_question.id
      expect(question['content']).to eq slider_question.content
      expect(question['position']).to eq slider_question.position
      expect(question['submit_label']).to eq slider_question.submit_label
      expect(question['empty_error_text']).to eq slider_question.empty_error_text || 'Required.'
      expect(question['slider_start_position']).to eq slider_question.slider_start_position.to_s
      expect(question['slider_submit_button_enabled']).to eq slider_question.slider_submit_button_enabled ? 't' : 'f'

      slider_possible_answers.each.with_index do |slider_possible_answer, index|
        possible_answer = question['possible_answers'][index]
        expect(possible_answer['id']).to eq slider_possible_answer.id
        expect(possible_answer['content']).to eq slider_possible_answer.content
        expect(possible_answer['position']).to eq slider_possible_answer.position
        expect(possible_answer['next_question_id']).to eq slider_possible_answer.next_question_id
      end
    end
  end
end
