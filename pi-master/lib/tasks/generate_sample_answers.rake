# frozen_string_literal: true

# Writes additional sample data for development
# A rough and wild development tool
#
# ACCOUNT_ID -- Optional: The ID of an existing Account to generate a survey and answers for
# ADMIN_USER_ID -- Optional: The ID of a user to link to the account for easier switching
# SURVEY_ID -- Optional: The ID of an existing survey to generate answers for
# START_DATE -- Optional: The date to start generating answers for (e.g. "2021-07-22")
# END_DATE -- Optional: The date to stop generating answers on (e.g. "2021-07-27")
# NUM_ANSWERS_PER_DAY -- Optional: The number of answers to generate per day
# SUBMISSION_RATE -- (0,100) Optional: The desired number of answers per impression.
# rubocop:disable Metrics/BlockLength It's a big 'ol mess

DEVICE_TYPES = %w(email native_mobile desktop mobile tablet) + [nil]

task generate_sample_answers: :environment do
  require "#{Rails.root}/lib/task_helpers/logging"
  include Logging

  task_name = ARGV[0]
  @logger = ActiveSupport::TaggedLogging.new(Logger.new(ENV["STD_OUT"] ? $stdout : "log/#{task_name}.log"))

  def main
    @logger.tagged task_name do
      log "------------------------------ Starting ------------------------------"

      log "Generating answers for: #{start_date} to #{end_date}"

      num_answers_per_day = ENV['NUM_ANSWERS_PER_DAY'].to_i || 100

      (start_date..end_date).each do |date|
        log "Generating #{num_answers_per_day} answers for #{date} --------------------------"

        num_answers_per_day.times do |_|
          generate_answers_for_date(date)
        end

        # we may have created more than num_answers_per_day records.
        # We'll actually have something like num_answers_per_day * num_questions
        submission_rate = ENV['SUBMISSION_RATE'].to_i || 100
        num_submissions = Submission.where(created_at: (date.beginning_of_day..date.end_of_day)).count
        num_impressions = num_submissions / submission_rate

        num_impressions.times do |_|
          generate_submission_for_date(date)
        end
      end

      log "account: #{account.name}(#{account.id}, survey: #{survey.name}(#{survey.id})"
      log "------------------------------ Done ------------------------------"
    end
  end

  def account
    unless @account
      if ENV['ACCOUNT_ID']
        @account = Account.find(ENV['ACCOUNT_ID'])
        log "Using existing account: #{@account.name}(#{@account.id})"
      else
        @account = Account.create(name: "#{FFaker::Color.name} -- #{FFaker::Lorem.unique.word}")
        log "Created new account: #{@account.name}(#{@account.id})"
      end

      user
    end

    @account
  end

  def user
    unless @user
      if ENV['ADMIN_USER_ID']
        @user = User.find(ENV['ADMIN_USER_ID'])

        AccountUser.create(account_id: account.id, user_id: ENV['ADMIN_USER_ID'])
        log "Linked #{User.find(ENV['ADMIN_USER_ID']).name} to the account"
      else
        password = 'abcD123$%'

        @user = User.create(
          first_name: FFaker::Lorem.unique.word,
          last_name: FFaker::Lorem.unique.word,
          email: FFaker::Internet.unique.email,
          password: password,
          account: account
        )

        log "Created new test user: #{@user.email} -- #{password}"
      end
    end

    @user
  end

  # rubocop:disable Metrics/AbcSize
  # Building surveys is complicated
  def survey
    unless @survey
      if ENV['SURVEY_ID']
        @survey = account.surveys.find_by(id: Survey.find(ENV['SURVEY_ID']))
        raise "survey not found for account" unless @survey
        log "Using existing survey: #{@survey.name}(#{@survey.id})"
      else
        @survey = account.surveys.create(name: "survey_with_answers_#{FFaker::Lorem.unique.word}")
        log "Created new survey: #{@survey.name}(#{@survey.id})"

        single_choice_question = @survey.questions.single_choice_question.create(
          content: "single_choice_question_#{FFaker::Lorem.unique.word}",
          position: 0
        )
        multiple_choice_question = @survey.questions.multiple_choices_question.create(
          content: "multiple_choice_question_#{FFaker::Lorem.unique.word}",
          position: 1
        )

        free_text_question = @survey.questions.free_text_question.create(
          content: "free_text_question_#{FFaker::Lorem.unique.word}",
          position: 2,
          keyword_extraction: generate_keyword_extractions
        )

        (2..5).to_a.sample.times do |i|
          single_choice_question.possible_answers.create(content: "SC PA #{i} #{FFaker::Lorem.unique.word}", next_question_id: multiple_choice_question.id)
          multiple_choice_question.possible_answers.create(content: "MCQ PA #{i} #{FFaker::Lorem.unique.word}")
        end

        multiple_choice_question.possible_answers.last.update(next_question_id: free_text_question.id)
      end
    end

    @survey
  end

  def generate_keyword_extractions
    keyword_extraction = {}
    10.times do |_|
      keyword_extraction[FFaker::Lorem.unique.word] = rand(100000) / 10000000.0
    end
    keyword_extraction
  end

  def generate_submission_for_date(date)
    create_viewed_impression = [true, false].sample

    device = Device.create(udid: SecureRandom.uuid)
    survey.submissions.create(device: device, created_at: date.noon,
                              viewed_at: (create_viewed_impression ? date.noon : nil),
                              device_type: DEVICE_TYPES.sample,
                              pageview_count: (1..100).to_a.sample,
                              visit_count: (1..100).to_a.sample)

    if cache_record = SurveySubmissionCache.find_by(survey_id: survey.id, applies_to_date: date)
      cache_record.increment!(:impression_count)
    else
      SurveySubmissionCache.create(
        survey_id: survey.id,
        applies_to_date: date.to_date,
        submission_count: 0,
        viewed_impression_count: create_viewed_impression ? 1 : 0,
        impression_count: 1,
        last_impression_at: date.noon
      )
    end
  end

  def generate_answers_for_date(date)
    device = Device.create(udid: SecureRandom.uuid)
    submission = survey.submissions.create(device: device, created_at: date.noon)

    if id = SurveySubmissionCache.where(survey_id: survey.id, applies_to_date: date).pick(:id)
      SurveySubmissionCache.update_counters(id, submission_count: 1, viewed_impression_count: 1, impression_count: 1, touch: true)
    else
      SurveySubmissionCache.create(
        survey_id: survey.id,
        applies_to_date: date.to_date,
        submission_count: 1,
        viewed_impression_count: 1,
        impression_count: 1,
        last_impression_at: date.noon
      )
    end

    survey.questions.each do |question|
      generate_answer_to_question(question, submission)
    end
  end

  def generate_answer_to_question(question, submission)
    if question.single_choice_question?
      question.answers.create(possible_answer: question.possible_answers.sample, submission: submission, created_at: submission.created_at)
    elsif question.multiple_choices_question?
      number_to_choose = (1..question.possible_answers.count).to_a.sample

      question.possible_answers.sample(number_to_choose).each do |possible_answer|
        question.answers.create(possible_answer: possible_answer, submission: submission, created_at: submission.created_at)
      end
    elsif question.free_text_question?
      answer_keywords = []
      question.keyword_extraction.each_pair do |k, v|
        answer_keywords << { "relevance" => (v.to_f / (k.length ** 2)).to_s, "text" => k }
      end

      question.answers.create(
        text_answer: FFaker::Lorem.phrase, submission: submission,
        created_at: submission.created_at, keyword_extraction: answer_keywords
      )
    end
  end

  def start_date
    @start_date ||= ENV['START_DATE'].to_date || 1.year.ago.to_date
  end

  def end_date
    @end_date ||= ENV['END_DATE'].to_date || Time.current.to_date
  end

  main
end
