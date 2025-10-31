# frozen_string_literal: true
require 'spec_helper'

describe NBA::WNBAFavouriteTeamsWorker do
  let(:valid_email_address) { FFaker::Internet.email }
  let(:worker) { described_class.new }
  let(:submission_udid) { '00000000-0000-4000-f000-000000000001' }
  let(:favourite_teams) { ["Seattle Storm", "Washington Mystics"] }

  def expected_payload(email_address = valid_email_address)
    {
      attributes: [{
        external_id: email_address,
        submission_udid: submission_udid,
        pulse_insights_favorite_wnba_teams: "SEA,WAS"
      }]
    }
  end

  it_behaves_like "braze reporter" do
    subject { worker }
  end

  before do
    survey = create(:survey_with_one_multiple_question)
    survey.reload
    question = survey.questions.first
    @possible_answers = question.possible_answers
    @possible_answers[0].update(content: favourite_teams[0])
    @possible_answers[1].update(content: favourite_teams[1])
  end

  it "calls braze with all required input when input is valid" do
    expect(worker).to receive(:send_to_braze).with(expected_payload)

    worker.perform(valid_email_address, @possible_answers.order(:id).pluck(:id), submission_udid)
  end
end
