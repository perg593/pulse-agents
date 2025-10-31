# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

class ExportAllSubmissionsWorker
  include Rack::PiLogger
  include Common
  include Sidekiq::Worker
  require 'csv'

  def perform(identifier)
    account = Account.find_by(identifier: identifier)

    sql = <<-SQL
      SELECT submissions.created_at submission_created_at,
        devices.udid,
        submissions.url,
        submissions.survey_id,
        answers.created_at answer_created_at,
        answers.question_id,
        possible_answers.content,
        answers.text_answer
      FROM "submissions"
      INNER JOIN "devices" ON "devices"."id" = "submissions"."device_id"
      LEFT JOIN answers ON answers.submission_id = submissions.id
      LEFT JOIN possible_answers ON possible_answers.id = answers.possible_answer_id
      WHERE "submissions"."survey_id" IN (#{account.surveys.pluck(:id).join(',')})
    SQL

    submissions = postgres_execute(sql)

    date = Time.current
    timestamp = date.strftime('%Y%m%d%H%M%S')
    filename = "tmp/EXPORT_ACCOUNT_#{identifier}_#{timestamp}.csv"

    CSV.open(filename, 'w', col_sep: ',') do |csv|
      csv << csv_headers

      submissions.each do |submission|
        answer_created_at = nil

        if submission['answer_created_at']
          answer_created_at = Time.zone.parse(submission['answer_created_at']).to_i
        end

        csv << [
          Time.zone.parse(submission['submission_created_at']).to_i,
          submission['udid'],
          submission['url'],
          submission['survey_id'],
          answer_created_at,
          submission['question_id'],
          submission['content'],
          submission['text_answer']
        ]
      end
    end
  end

  private

  def csv_headers
    ["TIMESTAMP", "DEVICE UDID", "URL", "SURVEY ID", "ANSWER TIMESTAMP", "QUESTION ID", "ANSWER", "FREE TEXT RESPONSE"]
  end
end
