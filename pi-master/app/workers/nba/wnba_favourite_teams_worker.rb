# frozen_string_literal: true

module NBA
  class WNBAFavouriteTeamsWorker
    include Sidekiq::Worker
    include NBABrazeCommon

    WNBA_FAVOURITE_TEAMS_SURVEY_ID = 6580
    WNBA_FAVOURITE_TEAMS_QUESTION_ID = 20926

    WNBA_TEAM_ABBREVIATIONS = {
      "Atlanta Dream" => "ATL",
      "Chicago Sky" => "CHI",
      "Connecticut Sun" => "CON",
      "Dallas Wings" => "DAL",
      "Indiana Fever" => "IND",
      "Las Vegas Aces" => "LVA",
      "Los Angeles Sparks" => "LAS",
      "Minnesota Lynx" => "MIN",
      "New York Liberty" => "NYL",
      "Phoenix Mercury" => "PHO",
      "Seattle Storm" => "SEA",
      "Washington Mystics" => "WAS",
      "None" => "None"
    }.freeze

    def perform(email_address, favourite_team_possible_answer_ids, submission_udid)
      tagged_logger.info "Started"

      email_address = NBABrazeCommon.clean_email_address(email_address)

      unless NBABrazeCommon.valid_email_address?(email_address)
        tagged_logger.info("Invalid Email: #{email_address}. Finished")
        return
      end

      favourite_teams = PossibleAnswer.where(id: favourite_team_possible_answer_ids).pluck(:content)
      favourite_teams_payload = favourite_teams.map { |team_name| WNBA_TEAM_ABBREVIATIONS[team_name] }.join(",")

      attributes = {
        external_id: email_address,
        submission_udid: submission_udid,
        pulse_insights_favorite_wnba_teams: favourite_teams_payload
      }

      payload = { attributes: [attributes] }

      tagged_logger.info "Request - payload: #{payload}"

      message, errors = send_to_braze(payload)

      tagged_logger.info "Response - message: #{message}, errors: #{errors}"
    rescue StandardError => e
      tagged_logger.error e
      Rollbar.error(e, "WNBAFavouritePlayersWorker Error", payload: payload)
    ensure
      tagged_logger.info "Finished"
    end

    private

    def braze_app
      "wnba_#{Rails.env}"
    end
  end
end
