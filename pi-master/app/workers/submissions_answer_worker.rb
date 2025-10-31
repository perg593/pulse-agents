# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class SubmissionsAnswerWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(identifier, submission_udid, question_id, answer_id, text_answer, custom_data, multiple_answer_ids, client_key = nil)
    client_key == 'null' ? nil : client_key

    PostAnswerWorker.new.perform(identifier, submission_udid, question_id, answer_id, text_answer, multiple_answer_ids)
    SaveCustomDataWorker.new.perform(submission_udid, custom_data) if custom_data
    UpdateClientKeyAltWorker.new.perform(submission_udid, client_key) if client_key

    fire_nba_braze_worker(submission_udid, answer_id, custom_data)
    fire_nba_favourite_players_worker(submission_udid, custom_data, text_answer, question_id)
    fire_wnba_favourite_teams_worker(submission_udid, multiple_answer_ids, custom_data, question_id)

    fire_azurity_adverse_event_worker(identifier, text_answer, submission_udid)
  end

  private

  def fire_wnba_favourite_teams_worker(submission_udid, favourite_team_possible_answer_ids, custom_data, question_id)
    return unless question_id.to_i == NBA::WNBAFavouriteTeamsWorker::WNBA_FAVOURITE_TEAMS_QUESTION_ID
    return unless submission = Submission.find_by(udid: submission_udid)
    return unless submission.survey_id == NBA::WNBAFavouriteTeamsWorker::WNBA_FAVOURITE_TEAMS_SURVEY_ID
    return unless email_address = extract_email_address(custom_data)

    NBA::WNBAFavouriteTeamsWorker.perform_async(email_address, favourite_team_possible_answer_ids, submission_udid)
  end

  def fire_nba_favourite_players_worker(submission_udid, custom_data, text_answer, question_id)
    return unless question_id.to_i == NBAFavouritePlayersWorker::NBA_FAVOURITE_PLAYER_QUESTION_ID
    return unless submission = Submission.find_by(udid: submission_udid)
    return unless submission.survey_id == NBAFavouritePlayersWorker::NBA_FAVOURITE_PLAYER_SURVEY_ID
    return unless email_address = extract_email_address(custom_data)

    favourite_player_names = begin
      JSON.parse(text_answer)
    rescue JSON::ParserError => e
      nil
    end

    return unless favourite_player_names.present?

    NBAFavouritePlayersWorker.perform_async(email_address, favourite_player_names, submission_udid)
  end

  # Send Email, Favorite NBA team to Braze
  def fire_nba_braze_worker(submission_udid, answer_id, custom_data)
    return unless submission = Submission.find_by(udid: submission_udid)

    # _Favorite Team (Began 2017-02-25)
    return unless submission.survey_id == 1132

    return unless email = extract_email_address(custom_data)

    NBABrazeWorker.perform_async("nba_#{Rails.env}", email, submission_udid, answer_id, nil, nil, nil)
  end

  def extract_email_address(custom_data)
    email = begin
      JSON.parse(custom_data.to_s)["email"]
    rescue JSON::ParserError => e
      nil
    end
  end

  def fire_azurity_adverse_event_worker(identifier, text_answer, submission_udid)
    return unless Azurity.adverse_event_account_identifier?(identifier)
    return unless text_answer.present?

    Azurity::AzurityAdverseEventWorker.perform_async(identifier, submission_udid)
  end
end
