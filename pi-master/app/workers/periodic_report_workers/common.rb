# frozen_string_literal: true

module PeriodicReportWorkers
  # rubocop:disable Metrics/ModuleLength
  module Common
    module ClassMethods
      def account_ids
        raise NotImplementedError, "#{self.class} included the Common module but didn't define account_ids!"
      end

      def survey_ids; end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def generate_qc_file(filepath, report_filename, report_data_range, report_filepath)
      tagged_logger.info "Generating quality control file for #{report_filename}"

      CSV.open(filepath, 'w') do |csv|
        sha256 = Digest::SHA256.file(report_filepath)
        report_checksum = sha256.hexdigest

        csv << %w(Feed_Name Record_Count Feed_Size Checksum Data_Period_Start Data_Period_End)

        csv << [
          report_filename,
          CSV.read(report_filepath).size - 1,
          File.size(report_filepath),
          report_checksum,
          report_data_range.first.strftime("%m/%d/%y"),
          report_data_range.last.strftime("%m/%d/%y")
        ]
      end

      tagged_logger.info "Done generating quality control file for #{report_filename}"
    end

    def generate_submission_report(filepath, report_data_range)
      tagged_logger.info "Generating submission data report"

      CSV.open(filepath, 'w') do |csv|
        csv << submission_report_mapper.keys

        submission_report_data(report_data_range).each { |datum| csv << submission_report_mapper(datum).values }
      end

      tagged_logger.info "Done generating submission data report"
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/BlockLength
    # rubocop:disable Metrics/AbcSize
    # There are a lot of columns to specify, and it gets complicated
    def submission_report_data(report_data_range)
      return @submission_report_data if @submission_report_data

      @submission_report_data = []

      survey_scope = Survey.includes(:account, answers: %i(device tags submission)).where(account_id: self.class.account_ids).order(:account_id, :name)

      survey_scope = survey_scope.where(id: self.class.survey_ids) if self.class.survey_ids

      survey_scope.each do |survey|
        survey.answers.where(created_at: report_data_range).order(:created_at).each do |answer|
          @submission_report_data << {
            "account_name" => survey.account.name,
            "account_id" => survey.account.identifier,
            "answer_creation_date" => answer.created_at.strftime("%m/%d/%y"),
            "answer_creation_time" => answer.created_at.strftime("%H/%M/%S"),
            "answer_creation_timestamp" => answer.created_at.strftime("%y-%m-%d %H:%M:%S.%6N"),
            "question_content" => answer.question.content,
            "text_response" => answer.text_of_response,
            "tags" => answer.tags.pluck(:name).join(","),
            "survey_id" => survey.id,
            "question_id" => answer.question.id,
            "answer_id" => answer.id,
            "next_question_id" => answer.next_question_id,
            "pageview_count" => answer.submission.pageview_count,
            "visit_count" => answer.submission.visit_count,
            "device_type" => answer.submission.device_type,
            "udid" => answer.device.udid,
            "client_key" => answer.submission.client_key,
            "url" => answer.submission.url,
            "view_name" => answer.submission.view_name,
            "pseudo_event" => answer.submission.pseudo_event,
            "custom_data" => answer.submission.custom_data,
            "device_data" => answer.device_data,
            "sentiment_score" => answer.sentiment.try(:[], 'score'),
            "sentiment_magnitude" => answer.sentiment.try(:[], 'magnitude'),
            "entity_1_name" => answer.entities.try(:[], 0).try(:[], 'name'),
            "entity_1_type" => answer.entities.try(:[], 0).try(:[], 'type'),
            "entity_2_name" => answer.entities.try(:[], 1).try(:[], 'name'),
            "entity_2_type" => answer.entities.try(:[], 1).try(:[], 'type'),
            "entity_3_name" => answer.entities.try(:[], 2).try(:[], 'name'),
            "entity_3_type" => answer.entities.try(:[], 2).try(:[], 'type'),
            "entity_4_name" => answer.entities.try(:[], 3).try(:[], 'name'),
            "entity_4_type" => answer.entities.try(:[], 3).try(:[], 'type'),
            "os" => answer.os,
            "browser" => answer.browser,
            "browser_version" => answer.browser_version,
            "channel" => answer.submission.channel
          }
        end
      end

      @submission_report_data
    end

    def submission_report_mapper(datum = {})
      {
        "Account Name" => datum["account_name"],
        "Account ID" => datum["account_id"],
        "Date" => datum["answer_creation_date"],
        "Time" => datum["answer_creation_time"],
        "Timestamp (UTC)" => datum["answer_creation_timestamp"],
        "Question" => datum["question_content"],
        "Response" => datum["text_response"],
        "Tags" => datum["tags"],
        "SurveyID" => datum["survey_id"],
        "QuestionID" => datum["question_id"],
        "ResponseID" => datum["answer_id"],
        "NextQuestionID" => datum["next_question_id"],
        "Pageview Count" => datum["pageview_count"],
        "Visit Count" => datum["visit_count"],
        "Device Type" => datum["device_type"],
        "DeviceUDID" => datum["udid"],
        "Client Key" => datum["client_key"],
        "Completion URL" => datum["url"],
        "View Name" => datum["view_name"],
        "Event" => datum["pseudo_event"],
        "Context data" => datum["custom_data"],
        "Device data" => datum["device_data"],
        "Sentiment Score" => datum["sentiment_score"],
        "Sentiment Magnitude" => datum["sentiment_magnitude"],
        "Entity 1 name" => datum["entity_1_name"],
        "Entity 1 type" => datum["entity_1_type"],
        "Entity 2 name" => datum["entity_2_name"],
        "Entity 2 type" => datum["entity_2_type"],
        "Entity 3 name" => datum["entity_3_name"],
        "Entity 3 type" => datum["entity_3_type"],
        "Entity 4 name" => datum["entity_4_name"],
        "Entity 4 type" => datum["entity_4_type"],
        "OS" => datum["os"],
        "Browser" => datum["browser"],
        "Browser version" => datum["browser_version"],
        "Channel" => datum["channel"]
      }
    end
  end
end
