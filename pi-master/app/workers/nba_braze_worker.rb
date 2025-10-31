# frozen_string_literal: true

class NBABrazeWorker
  include Sidekiq::Worker
  include NBABrazeCommon

  BIRTHDAY_QUESTION_IDS = [6106, 6107, 6108].freeze # Month, Day, Year

  def perform(braze_app, email, submission_udid, favorite_team_id, birthday_ids, sign_up_date, subscribed)
    tagged_logger.info 'Started'

    @braze_app = braze_app

    tagged_logger.info "Braze App: #{braze_app}"

    email = NBABrazeCommon.clean_email_address(email)

    tagged_logger.info("Invalid Email: #{email}. Finished") && return unless NBABrazeCommon.valid_email_address?(email)

    team = fetch_favorite_team(favorite_team_id)
    bday = fetch_birthday(birthday_ids)

    payload = braze_attributes(submission_udid, email, favorite_team: team, birthday: bday, sign_up_date: sign_up_date, subscribed: subscribed)

    tagged_logger.info "Request - payload: #{payload}"

    message, errors = send_to_braze(payload)

    # response structure: https://www.braze.com/docs/api/endpoints/user_data/post_user_track/#user-track-responses
    tagged_logger.info "Response - message: #{message}, errors: #{errors}"
    Rollbar.error("NBABrazeWorker Response Fatal", payload: payload, message: message, errors: errors) unless message == 'success'
    true
  rescue StandardError => e
    tagged_logger.error e
    Rollbar.error(e, "NBABrazeWorker Error", payload: payload)
  ensure
    message ||= ''
    payload ||= {}
    log_worker_activity_to_influxdb(success: message == 'success', input: payload)
    tagged_logger.info 'Finished'
  end

  private

  attr_reader :braze_app

  # Data structure: https://www.braze.com/docs/api/endpoints/user_data/post_user_track/#request-body
  # List of standard columns: https://www.braze.com/docs/user_guide/data_and_analytics/user_data_collection/user_import/#constructing-your-csv
  #
  # Sending Submission udid because we need something other than external_id to send
  # to make a successful request, and Submission udid could be helpful when troubleshooting
  def braze_attributes(submission_udid, email, favorite_team: nil, birthday: nil, sign_up_date: nil, subscribed: nil)
    attributes =
      {
        external_id: email, # Standard column for a user's identifier
        dob: birthday, # Standard column that stands for "Date of Birth"
        submission_udid: submission_udid,
        Pulse_Insights_Sub_Date: sign_up_date,
        Pulse_Insights_Subscribed: subscribed
      }

    favorite_team_key = braze_app.include?('wnba') ? :favorite_wnba_team : :favorite_nba_team
    attributes[favorite_team_key] = favorite_team

    { attributes: [attributes.compact] }
  end

  def fetch_favorite_team(favorite_team_id)
    full_name = PossibleAnswer.find_by_id(favorite_team_id)&.content
    abbreviated_team_name[full_name]
  end

  def fetch_birthday(birthday_ids)
    return if birthday_ids.nil?

    month, day, year = PossibleAnswer.unscoped.where(id: birthday_ids, question_id: BIRTHDAY_QUESTION_IDS).order(:question_id).pluck(:content)

    Date.parse("#{year}#{month}#{day}").strftime("%Y-%m-%d") # E.g. 1970 Apr 4 => 1970-4-4
  rescue ArgumentError => e # rescuing invalid user input
    tagged_logger.error("#{e}: #{year} #{month} #{day}")
    nil
  end

  # A mapper from a full team name to an abbreviated team name. E.g. Atlanta Hawks => ATL
  def abbreviated_team_name
    YAML.load_file("#{Rails.root}/config/nba_team_name_abbreviations.yml")
  end
end
