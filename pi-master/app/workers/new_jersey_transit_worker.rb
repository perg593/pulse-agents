# frozen_string_literal: true
require 'csv'
require 'hubspot-api-client'

class NewJerseyTransitWorker
  include Sidekiq::Worker
  include ::Common
  include ClientReports::StatusLogger

  HUBSPOT_LABEL_BY_QUESTION = {
    18526 => "pulseinsights_travelchoice",
    19615 => "pulseinsights_rewardsvalue",
    20683 => "pulseinsights_foundoffers",
    20970 => "pulseinsights_studentpassother",
    22395 => "pulseinsights_chooserewards",
    23527 => "Postal code"
  }.freeze

  QUESTION_IDS = [
    18526, # When you travel on NJ Transit, is it primarily for work/commuting or leisure? Survey #6095
    19615, # How valuable are these rewards offers to you? Survey #6383
    20683, # Have you found rewards offers near you? Survey #6585
    20970, # Where else do you travel using NJ TRANSIT? Survey #6637
    22395, # What do you want to see more of on NJT Rewards? Survey #7016
    23527 # What is your ZIP code? #7270
  ].freeze

  # rubocop: disable Metrics/MethodLength
  def perform(custom_start_date: nil, custom_end_date: nil)
    tagged_logger.info "Started"

    @start_at = custom_start_date || 1.week.ago.beginning_of_day
    @end_at = custom_end_date || Time.current
    tagged_logger.info "From #{@start_at} to #{@end_at}"

    answers = Answer.where(question_id: QUESTION_IDS, created_at: @start_at..@end_at)
    tagged_logger.info "Found #{answers.count} answer(s)"

    answers = answers.joins(:possible_answer, :submission)
    answers = answers.where("submissions.custom_data::jsonb ->> 'contactid' IS NOT NULL")
    contacts = answers.select(<<-SQL).order('contact_id, answers.created_at DESC')
      DISTINCT ON (contact_id)
        answers.question_id,
        possible_answers.content,
        submissions.custom_data::jsonb ->> 'contactid' contact_id
    SQL
    tagged_logger.info "Found #{contacts.size} contact(s)"

    inputs = contacts.map do |contact|
      {
        id: contact.contact_id,
        properties: {
          HUBSPOT_LABEL_BY_QUESTION[contact.question_id] => contact.content
        }
      }
    end
    send_to_hubspot(inputs) unless inputs.blank?

    tagged_logger.info "Preparing worker execution confirmation file"
    send_confirmation_file_to_s3(contacts)

    record_success(@start_at)
  # TODO: Should we report this error?
  rescue StandardError => e
    record_failure(@start_at)
  ensure
    tagged_logger.info "Finished"
  end

  # data_start_time -- the beginning of a week
  def self.delivered_as_expected?(data_start_time = 1.week.ago.beginning_of_week)
    ClientReports::ClientReportHistory.for_job_class(self).succeeded.where(data_start_time: data_start_time).exists?
  end

  private

  def send_confirmation_file_to_s3(contacts)
    output_filename = "njt_output_#{@start_at.strftime("%Y-%m-%dT%H:%M")}_#{@end_at.strftime("%Y-%m-%dT%H:%M")}.csv"
    output_filepath = "tmp/#{output_filename}"

    CSV.open(output_filepath, 'w') do |csv|
      csv << ["contact count"]
      csv << [contacts.size]
    end

    upload_copy_to_s3(output_filename)
  end

  def send_to_hubspot(inputs)
    api_client = Hubspot::Client.new(access_token: Rails.application.credentials.hubspot[:access_token])

    retry_config = {
      500..530 => { max_retries: 2, seconds_delay: 2 },
      400 => { max_retries: 3, seconds_delay: 3 },
      429 => { max_retries: 3, seconds_delay: 30 } # "Rate limit exceeded" means we should try less frequently
    }

    # Hubspot sets the limit of "100 records per call": https://developers.hubspot.com/docs/api/crm/understanding-the-crm
    inputs.in_groups_of(100) do |grouped_inputs|
      api_client.crm.contacts.batch_api.update(body: { inputs: grouped_inputs }, retry: retry_config) do |error|
        Rollbar.error("Hubspot Error #{error.code}", message: error.message, inputs: grouped_inputs)
      end
    end
  end
end
