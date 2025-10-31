# frozen_string_literal: true
require 'spec_helper'

describe SurveyBriefGenerator do
  let(:survey) { create(:survey) }

  let(:stubbed_summary) { 'a' }
  let(:response_body) { "{\"choices\":[{\"message\":{\"content\":\"#{stubbed_summary}\"}}]}" }

  before do
    stubbed_url = "https://api.openai.com/v1/chat/completions"
    stubbed_headers = {
      'Accept'=>'*/*',
      'Authorization'=>'Bearer NONE',
      'Content-Type'=>'application/json',
      'User-Agent'=>'Ruby'
    }

    @stubbed_request = stub_request(:post, stubbed_url).
                       with(headers: stubbed_headers).
                       with { |req| req.body =~ /gpt-4-turbo/ }.
                       with { |req| req.body =~ /#{survey.summarize}/ }.
                       to_return_json(status: 200, body: response_body, headers: {})
  end

  describe "generate" do
    let(:generator) { described_class.new(survey) }

    it "calls Open AI's API" do
      generator.generate

      expect(@stubbed_request).to have_been_requested
    end

    it "returns a string" do
      expect(generator.generate).to be_a String
    end
  end
end
