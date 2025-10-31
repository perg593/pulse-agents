# frozen_string_literal: true

require "#{Rails.root}/lib/task_helpers/logging"

# Generally only safe to do after wiping all customAttributes
# This is more for QA or development purposes.
# TODO: Consider shortening
# rubocop:disable Metrics/BlockLength
task generate_sample_custom_attributes: :environment do
  def task_name
    "generate_sample_custom_attributes"
  end

  def main
    logger = ActiveSupport::TaggedLogging.new(Logger.new("log/#{task_name}.log"))

    logger.info "------------------------------ Starting ------------------------------"

    unless ENV["ACCOUNT_ID"]
      logger.info "ACCOUNT_ID not set -- exiting"
      return
    end

    account = Account.find(ENV["ACCOUNT_ID"])

    unless account.registered_with_qrvey?
      logger.info "Account not registered with Qrvey -- exiting"
      return
    end

    qrvey_user = account.qrvey_user

    qrvey_application_id = qrvey_user.qrvey_applications.first.qrvey_application_id
    qrvey_user_id = qrvey_user.qrvey_user_id

    qrvey_dashboard_responses = QrveyBridge.get_all_dashboards(qrvey_user_id, qrvey_application_id)

    qrvey_dashboard_responses.each do |qrvey_dashboard_response|
      custom_attributes = QrveyBridge::CustomAttributes.new

      custom_attributes.owner_id = account.users.sample.id

      share_with_user_id = account.users.where.not(id: custom_attributes.owner_id).sample.id
      access_level = [
        QrveyBridge::CustomAttributes::ACCESS_LEVEL_VIEWER,
        QrveyBridge::CustomAttributes::ACCESS_LEVEL_EDITOR
      ].sample

      custom_attributes.share_with(share_with_user_id, access_level)

      body = custom_attributes.to_h

      QrveyClient.patch_dashboard(qrvey_user_id, qrvey_application_id, qrvey_dashboard_response.dashboard_id, body)
    end

    logger.info "------------------------------ Done ------------------------------"
  end

  main
end

# **********************************************************
# * WARNING: This will erase all customAttributes on Qrvey *
# **********************************************************
task wipe_custom_attributes: :environment do
  def task_name
    "wipe_custom_attributes"
  end

  def main
    logger = ActiveSupport::TaggedLogging.new(Logger.new("log/#{task_name}.log"))

    logger.info "------------------------------ Starting ------------------------------"

    unless ENV["DELETE_ALL_FOR_REALZ"] == "FOR_REALZ"
      logger.info "Please reconsider -- exiting"
      return
    end

    Account.all.each do |account|
      next unless account.registered_with_qrvey?

      logger.info "Account #{account.id} registered with Qrvey"

      qrvey_user = account.qrvey_user

      qrvey_application_id = qrvey_user.qrvey_applications.first.qrvey_application_id
      qrvey_user_id = qrvey_user.qrvey_user_id

      body = {
        "customAttributes" => nil
      }

      items = QrveyClient.get_all_dashboards(qrvey_user_id, qrvey_application_id)["Items"]
      responses = items.reject { |item| item["customAttributes"].nil? }.map { |item| QrveyDashboardResponse.new(item) }

      logger.info "Found #{responses} dashboards with custom attributes defined"
      next if responses.empty?

      dashboard_ids = responses.map(&:dashboard_id).compact

      dashboard_ids.each do |dashboard_id|
        QrveyClient.patch_dashboard(qrvey_user_id, qrvey_application_id, dashboard_id, body)
      end
    end

    logger.info "------------------------------ Done ------------------------------"
  end

  main
end
