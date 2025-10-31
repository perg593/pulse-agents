# frozen_string_literal: true
require 'spec_helper'

describe SurveyRecommendationWorker do
  let(:survey) { create(:survey) }
  let(:filters) { { "key" => "value" } }
  let(:gpt_response_content) do
    [
      {
        title: "Title of this next learning",
        reasoning: "Because users said X, consider next learning Y.",
        question: "Proposed survey question",
        possibleAnswers: ["Answer 1", "Answer 2", "Answer 3"],
        targeting: "Proposed targeting",
        expectedBenefit: "Expected Benefit"
      }
    ].to_json
  end
  let(:gpt_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => gpt_response_content
          }
        }
      ]
    }
  end

  before do
    allow(GPT).to receive(:chat).and_return(gpt_response)
  end

  describe "#perform" do
    describe "prompt" do
      let(:submission) { create(:submission, survey: survey) }

      let(:single_choice_question) { create(:single_choice_question, survey: survey) }

      let(:free_text_question) { create(:free_text_question, survey: survey) }
      let!(:free_text_answer) { create(:free_text_answer, question: free_text_question, submission: submission) }

      before do
        create(:answer, question: single_choice_question, submission: submission)
      end

      it "calls GPT.chat with a prompt containing survey data" do
        expect(GPT).to receive(:chat) do |prompt|
          expect(prompt).to include("Based on the following survey data")
          expect(prompt).to include("recommend 6 questions")

          expect(prompt).to match(/"account_name".*#{survey.account.name}/)
          expect(prompt).to match(/"name".*#{survey.name}/)

          expect(prompt).to match(/"sample_rate".*#{survey.sample_rate}/)
          expect(prompt).to match(/"desktop".*#{survey.desktop_enabled}/)
          expect(prompt).to match(/"mobile".*#{survey.mobile_enabled}/)

          expect(prompt).to match(/"question".*#{single_choice_question.content}/)
          expect(prompt).to match(/"total_responses".*\d+/)
          expect(prompt).to include("response_distribution")

          expect(prompt).to match(/"question".*#{free_text_question.content}/)
          expect(prompt).to match(/"response".*#{free_text_answer.text_answer}/)
          expect(prompt).to match(/"device_type".*#{submission.device_type}/)
          expect(prompt).to match(/"completion_url".*#{submission.url}/)

          gpt_response
        end

        described_class.new.perform(survey.id, filters)
      end
    end

    it "creates a recommendation with the correct attributes" do
      expect do
        described_class.new.perform(survey.id, filters)
      end.to change(SurveyRecommendation, :count).by(1)

      recommendation = SurveyRecommendation.last
      expect(recommendation.survey_id).to eq(survey.id)
      expect(recommendation.content).to eq(JSON.parse(gpt_response_content))
      expect(recommendation.filters).to eq(filters)
    end

    it "broadcasts the recommendation to the ActionCable channel" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "survey_recommendations_#{survey.id}",
        {
          'id' => kind_of(Integer),
          'content' => JSON.parse(gpt_response_content),
          'created_at' => kind_of(String),
          'filters' => filters
        }
      )

      described_class.new.perform(survey.id, filters)
    end

    context "when GPT returns an error" do
      let(:error_message) { "API rate limit exceeded" }
      let(:gpt_response) { { "error" => error_message } }

      it "broadcasts the error message to the ActionCable channel" do
        expect(ActionCable.server).to receive(:broadcast).with("survey_recommendations_#{survey.id}", error_message)

        described_class.new.perform(survey.id, filters)
      end
    end

    context "when an exception occurs" do
      let(:error_message) { "Test error" }

      before do
        allow(Survey).to receive(:find).and_raise(StandardError.new(error_message))
      end

      it "broadcasts the error message to the ActionCable channel" do
        expect(ActionCable.server).to receive(:broadcast).with("survey_recommendations_#{survey.id}", error_message)

        described_class.new.perform(survey.id, filters)
      end
    end
  end
end
