# frozen_string_literal: true
require 'spec_helper'

describe SummerDiscovery::SummerDiscoveryWorker do
  before do
    survey = create(:survey)

    described_class::KLAVIYO_KEY_BY_QUESTION_ID.each_key do |question_id|
      create(:multiple_choices_question, survey: survey, id: question_id)
    end
  end

  describe "ClientReportHistory" do
    let(:data_start_time) { 1.week.ago.beginning_of_day }

    context "when the report is successfully delivered" do
      before do
        described_class.new.perform
      end

      include_examples "status logger logs success"
    end

    context "when the report fails" do
      before do
        job_class = described_class.new
        allow(job_class).to receive(:record_success).and_raise(StandardError)

        job_class.perform
      end

      include_examples "status logger logs failure"
    end
  end

  describe "Delivery" do
    let(:klaviyo_profile_id) { "1234" }

    before do
      first_question = Question.find(described_class::KLAVIYO_KEY_BY_QUESTION_ID.keys.first)
      second_question = Question.find(described_class::KLAVIYO_KEY_BY_QUESTION_ID.keys.second)

      submission = create(:submission, survey: Survey.first, custom_data: {"KlaviyoID" => klaviyo_profile_id})
      create(:answer, question: first_question, submission: submission, created_at: 1.week.ago)
      create(:answer, question: first_question, possible_answer: first_question.possible_answers.last, submission: submission, created_at: 1.week.ago)

      submission = create(:submission, survey: Survey.first, custom_data: {"KlaviyoID" => klaviyo_profile_id})
      create(:answer, question: second_question, submission: submission, created_at: 1.week.ago)

      submission = create(:submission, survey: Survey.first, url: "#{FFaker::Internet.http_url}?KlaviyoID=#{klaviyo_profile_id}")
      create(:answer, question: first_question, submission: submission, created_at: 1.week.ago)
    end

    it "sends data via Klaviyo" do
      klaviyo_request = stub_request(:patch, "https://a.klaviyo.com/api/profiles/#{klaviyo_profile_id}").
                        to_return(status: 200, body: "", headers: {})

      job_class = described_class.new
      job_class.perform

      expect(klaviyo_request).to have_been_requested.times(Submission.count)
    end
  end
end
