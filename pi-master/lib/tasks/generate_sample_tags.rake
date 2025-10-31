# frozen_string_literal: true

# Writes tag data for development
#
# QUESTION_ID -- Required: The ID of an existing Question to generate tags for

# rubocop:disable Metrics/BlockLength
task generate_sample_tags: :environment do
  require "#{Rails.root}/lib/task_helpers/logging"
  include Logging

  task_name = ARGV[0]
  @logger = ActiveSupport::TaggedLogging.new(Logger.new(ENV["STD_OUT"] ? $stdout : "log/#{task_name}.log"))

  @logger.tagged task_name do
    log "------------------------------ Starting ------------------------------"

    question = Question.find(ENV["QUESTION_ID"])

    log "Generating tags for: question (#{question.id}) #{question.content}"

    10.times { Tag.create(name: FFaker::Lorem.unique.word, color: FFaker::Color.name, question: question) }

    question.answers.each do |answer|
      score = rand(-1000..1000) / 1000.0
      magnitude = rand(0..1000)
      magnitude /= 1000.0 unless magnitude.zero?

      answer.update(sentiment: {"score" => score, "magnitude" => magnitude})

      2.times do |_|
        tag = ([nil] + question.tags.to_a).sample

        unless tag
          log "Not applying a tag"
          next
        end

        tag_automation_job = [true, false].sample ? question.tag_automation_jobs.create : nil
        is_good_automation = [true, false].sample if tag_automation_job

        log "Applying tag #{tag.name}. automated? #{tag_automation_job.present?}. is_good_automation? #{is_good_automation}"
        AppliedTag.create(answer: answer, tag: tag, tag_automation_job: tag_automation_job, is_good_automation: is_good_automation)
      end
    end

    log "------------------------------ Done ------------------------------"
  end
end
