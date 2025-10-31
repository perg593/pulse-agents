# frozen_string_literal: true

# rubocop:disable Metrics/ParameterLists

require File.join(File.dirname(__FILE__), 'common')
require File.join(File.dirname(__FILE__), 'create_device_worker')
require File.join(File.dirname(__FILE__), 'create_impression_worker')
require File.join(File.dirname(__FILE__), 'post_answer_worker')
require File.join(File.dirname(__FILE__), 'save_custom_data_worker')

class DirectSubmissionWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  # rubocop:disable Metrics/MethodLength Deferring refactoring
  def perform(identifier, udid, survey_id, url, ip_address, user_agent, custom_data, question_id, answer_id, text_answer, submission_udid = nil)
    # Create device
    device = CreateDeviceWorker.new.perform(udid)

    # Record impression
    submission_udid ||= SecureRandom.uuid
    CreateImpressionWorker.new.perform(
      'survey_id' => survey_id,
      'udid' => submission_udid,
      'device' => device,
      'url' => url,
      'ip_address' => ip_address,
      'user_agent' => user_agent,
      'custom_data' => custom_data
    )
    UpdateSubmissionViewedAtWorker.perform_async(submission_udid, Time.current.to_s)

    # Post answer
    begin
      answer = PostAnswerWorker.new.perform(identifier, submission_udid, question_id, answer_id, text_answer, nil)
    rescue StandardError => e
      Rollbar.error e
      log_time if respond_to?(:log_time)
      return
    end

    custom_data = JSON.parse(custom_data) if custom_data.is_a?(String)
    fire_nba_favourite_players_worker(survey_id, submission_udid, custom_data, text_answer, question_id)

    fire_azurity_adverse_event_worker(identifier, text_answer, submission_udid)

    if answer
      log 'Posted answer'
      log answer.inspect

      # Update custom data because it may have changed since the submission has been created
      SaveCustomDataWorker.new.perform(submission_udid, custom_data) if custom_data&.any?

      # https://gitlab.ekohe.com/ekohe/pi/-/issues/1519, https://gitlab.ekohe.com/ekohe/pi/-/issues/1653
      fire_nba_braze_worker(submission_udid, custom_data, answer_id)
    else
      log 'Answer not posted'
      return
    end
  end

  private

  def fire_nba_favourite_players_worker(survey_id, submission_udid, custom_data, text_answer, question_id)
    return unless question_id.to_i == NBAFavouritePlayersWorker::NBA_FAVOURITE_PLAYER_QUESTION_ID
    return unless survey_id == NBAFavouritePlayersWorker::NBA_FAVOURITE_PLAYER_SURVEY_ID
    return unless email_address = custom_data.try(:[], "email")

    favourite_player_names = begin
      JSON.parse(text_answer)
    rescue JSON::ParserError => e
      nil
    end

    return unless favourite_player_names.present?

    NBAFavouritePlayersWorker.perform_async(email_address, favourite_player_names, submission_udid)
  end

  # Send Email and Favorite NBA team to Braze
  def fire_nba_braze_worker(submission_udid, custom_data, answer_id)
    return unless email = custom_data.try(:[], "email")
    return unless submission = Submission.find_by(udid: submission_udid)

    sign_up_date, subscribed = [nil] * 2

    case submission.survey_id
    when 1132 # NBA _Favorite Team (Began 2017-02-25)
      braze_app = "nba_#{Rails.env}"
    when 2119 # _Favorite Team WNBA
      braze_app = "wnba_#{Rails.env}"
      sign_up_date = submission.created_at.in_time_zone("America/New_York").iso8601
      subscribed = 'Y'
    else
      return
    end

    NBABrazeWorker.perform_async(braze_app, email, submission_udid, answer_id, nil, sign_up_date, subscribed)
  end

  def fire_azurity_adverse_event_worker(identifier, text_answer, submission_udid)
    return unless Azurity.adverse_event_account_identifier?(identifier)
    return unless text_answer.present?
    return unless submission_udid

    Azurity::AzurityAdverseEventWorker.perform_async(identifier, submission_udid)
  end
end
