# frozen_string_literal: true

RSpec.shared_examples "favourite players reporter" do
  let(:udid)  { '00000000-0000-4000-f000-000000000001' }
  let(:udid2) { '00000000-0000-4000-f000-000000000002' }

  let(:valid_survey) do
    survey = create(:survey_with_one_free_question, id: 5708)
    survey.reload
    survey.questions.first.update(id: 17050)
    survey
  end

  let(:valid_email_address) { FFaker::Internet.email }
  let(:valid_custom_data) { JSON.dump({"email" => valid_email_address }) }
  let(:custom_data_no_email_address) { JSON.dump({"irrelevant_key" => FFaker::Internet.email }) }

  let(:valid_favourite_player_names) { ["Michael Jordan", "Shaquille O'neil"] }
  let(:valid_favourite_players) { JSON.dump(valid_favourite_player_names) }

  let(:device) { create(:device, udid: udid) }

  let(:wrong_survey) { create(:survey_with_one_free_question, id: 1) }

  let(:survey) { valid_survey }
  let(:question) { survey.questions.last }

  let(:submission) { create(:submission, device_id: device.id, survey_id: survey.id, udid: udid2, answers_count: 0) }
  let(:submission_for_wrong_survey) { create(:submission, device_id: device.id, survey_id: wrong_survey.id, udid: udid, answers_count: 0) }

  # --------------------------------------------------------------------------
  # Creates an array representing the arguments necessary to create the worker
  #
  # @param survey - the survey the submission is for
  # @param submission - the survey taker's submission
  # @param custom_data - a json object
  # @param question - the question for the submission
  # @param text_answer - a json encoded string of favourite players
  # --------------------------------------------------------------------------
  def worker_arguments(_survey, _submission, _custom_data, _question, _text_answer)
    raise NotImplementedError, "You must implement 'worker_arguments' to use 'favourite players reporter'"
  end

  it "queues a favourite players worker if this is the favourite players survey" do
    valid_arguments = worker_arguments(survey, submission, valid_custom_data, question.id.to_s, valid_favourite_players)

    described_class.new.perform(*valid_arguments)

    expect(NBAFavouritePlayersWorker.jobs.size).to eq(1)
    job_args = NBAFavouritePlayersWorker.jobs.first["args"]
    expect(job_args).to contain_exactly(valid_email_address, valid_favourite_player_names, submission.udid)
  end

  it "does not queue a favourite players worker if this is not the favourite players survey" do
    survey = wrong_survey
    submission = submission_for_wrong_survey

    wrong_survey_arguments = worker_arguments(survey, submission, valid_custom_data, question.id.to_s, valid_favourite_players)

    described_class.new.perform(*wrong_survey_arguments)

    expect(NBAFavouritePlayersWorker.jobs.size).to eq(0)
  end

  it "does not queue a favourite players worker if this is not the right question" do
    question.update(id: 1)

    arguments = worker_arguments(survey, submission, valid_custom_data, question.id.to_s, valid_favourite_players)

    described_class.new.perform(*arguments)

    expect(NBAFavouritePlayersWorker.jobs.size).to eq(0)
  end

  it "does not queue a favourite players worker if the custom_data is nil" do
    arguments = worker_arguments(survey, submission, nil, question.id.to_s, valid_favourite_players)

    described_class.new.perform(*arguments)

    expect(NBAFavouritePlayersWorker.jobs.size).to eq(0)
  end

  it "does not queue a favourite players worker if the custom_data did not include an e-mail address" do
    arguments = worker_arguments(survey, submission, custom_data_no_email_address, question.id.to_s, valid_favourite_players)

    described_class.new.perform(*arguments)

    expect(NBAFavouritePlayersWorker.jobs.size).to eq(0)
  end

  it "does not queue a favourite players worker if there were no favourite players specified" do
    [
      JSON.dump([]),
      JSON.dump(nil),
      JSON.dump("")
    ].each do |invalid_favourite_players|
      arguments = worker_arguments(survey, submission, valid_custom_data, question.id.to_s, invalid_favourite_players)
      described_class.new.perform(*arguments)
      expect(NBAFavouritePlayersWorker.jobs.size).to eq(0)
    end
  end
end
