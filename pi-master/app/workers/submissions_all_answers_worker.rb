# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class SubmissionsAllAnswersWorker
  include Sidekiq::Worker
  include Rack::PiLogger
  include Common

  def perform(identifier, submission_udid, answers, custom_data, client_key = nil)
    client_key = nil if client_key == 'null'

    answers.each do |answer|
      case answer['question_type']
      when 'single_choice_question', 'slider_question'
        PostAnswerWorker.new.perform(identifier, submission_udid, answer['question_id'], answer['answer'], nil, nil)
      when 'free_text_question'
        PostAnswerWorker.new.perform(identifier, submission_udid, answer['question_id'], nil, answer['answer'], nil)
      when 'multiple_choices_question'
        PostAnswerWorker.new.perform(identifier, submission_udid, answer['question_id'], nil, nil, answer['answer'])
      end
    end

    SaveCustomDataWorker.new.perform(submission_udid, custom_data) if custom_data
    UpdateClientKeyAltWorker.new.perform(submission_udid, client_key) if client_key

    # https://gitlab.ekohe.com/ekohe/pi/issues/1143
    NeutrogenaFeedbackWorker.perform_async(submission_udid, answers) if identifier == "PI-45162694" # Neutrogena account

    # https://gitlab.ekohe.com/ekohe/pi/-/issues/1519, https://gitlab.ekohe.com/ekohe/pi/-/issues/1600
    fire_nba_braze_worker(submission_udid, answers)

    fire_azurity_adverse_event_worker(identifier, answers, submission_udid)
  end

  private

  # Send Email, Favorite NBA team, Birthday to Braze
  def fire_nba_braze_worker(submission_udid, answers)
    return unless submission = Submission.find_by(udid: submission_udid)

    favorite_team_id, birthday_ids, sign_up_date, subscribed = [nil] * 4

    case submission.survey_id
    when 2942 # ProPro | DOB Capture - This survey contains the user's email in the referer url's parameters
      braze_app = "nba_#{Rails.env}"
      email = parse_url_params(Submission.find_by(udid: submission_udid).url)['email']
      birthday_ids = answers.map { |r| r['answer'] }
    # Pausing temporarily for https://gitlab.ekohe.com/ekohe/pi/-/issues/1650
    # when 4467 # 2020-08-17 Email Capture | NBA Tickets
    #   braze_app = "nba_#{Rails.env}"
    #   email = answers.find { |a| a['question_type'] == 'free_text_question' }['answer']
    #   favorite_team_id = answers.find { |a| a['question_type'] == 'single_choice_question' }['answer']
    when 4835 # 2020-12 WNBA Overlay | Subscribe | Free Text
      braze_app = "wnba_#{Rails.env}"
      email = answers.find { |a| a['question_type'] == 'free_text_question' }['answer']
      sign_up_date = submission.created_at.in_time_zone("America/New_York").iso8601
      subscribed = 'Y'
    end

    NBABrazeWorker.perform_async(braze_app, email, submission_udid, favorite_team_id, birthday_ids, sign_up_date, subscribed) if email
  end

  def fire_azurity_adverse_event_worker(identifier, answers, submission_udid)
    return unless Azurity.adverse_event_account_identifier?(identifier)
    return unless submission_udid

    return unless answers.any? do |answer|
      answer["question_type"] == "free_text_question"
    end

    Azurity::AzurityAdverseEventWorker.perform_async(identifier, submission_udid)
  end
end
