# frozen_string_literal: true

class NBAFavouritePlayersWorker
  include Sidekiq::Worker
  include NBABrazeCommon

  NBA_FAVOURITE_PLAYER_SURVEY_ID = 5708
  NBA_FAVOURITE_PLAYER_QUESTION_ID = 17050

  def perform(email_address, favourite_player_names, submission_udid)
    tagged_logger.info "Started"

    email_address = NBABrazeCommon.clean_email_address(email_address)

    tagged_logger.info("Invalid Email: #{email_address}. Finished") && return unless NBABrazeCommon.valid_email_address?(email_address)

    attributes = {
      external_id: email_address,
      submission_udid: submission_udid,
      pulse_favoritePlayer: favourite_player_names
    }

    payload = { attributes: [attributes] }

    tagged_logger.info "Request - payload: #{payload}"

    message, errors = send_to_braze(payload)

    tagged_logger.info "Response - message: #{message}, errors: #{errors}"
  rescue StandardError => e
    tagged_logger.error e
    Rollbar.error(e, "NBAFavouritePlayersWorker Error", payload: payload)
  ensure
    tagged_logger.info "Finished"
  end

  private

  def braze_app
    "nba_#{Rails.env}"
  end
end
