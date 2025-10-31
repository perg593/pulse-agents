# frozen_string_literal: true
module Admin
  class SubmissionsController < BaseController
    DEVICE_TYPES = %w(email native_mobile desktop mobile tablet) + [nil]

    before_action :set_presenter

    # TODO: Handle record creation outside of the request cycle
    def generate_samples
      survey = Survey.where(id: params[:survey_id]).first

      unless survey
        flash.now.alert = "There was a problem generating sample submissions"
        render :sample_generator, status: 404 and return
      end

      num_submissions_created = 0

      num_impressions_to_create.times do |index|
        creation_date = choose_creation_date

        device = Device.create(udid: SecureRandom.uuid)

        submission = Submission.create(survey: survey, device: device, device_type: DEVICE_TYPES.sample, url: choose_completion_url, created_at: creation_date)

        should_create_viewed_impression = index < [num_viewed_impressions_to_create, num_submissions_to_create].max
        submission.update(viewed_at: creation_date + rand(10).seconds) if should_create_viewed_impression # Widget appears shortly after surveys.js has run

        should_create_submission = num_submissions_created < num_submissions_to_create

        if should_create_submission
          question = survey.questions.sample
          generate_answer_to_question(question, submission)
          submission.increment!(:answers_count)
          num_submissions_created += 1
        end

        update_cache(survey, creation_date, should_create_viewed_impression, should_create_submission)
      end

      redirect_to sample_generator_admin_submissions_path, alert: "Generated #{num_submissions_created} submissions!"
    end

    def questions
      render json: { error: 'Missing survey ID' }, status: 404 and return unless params[:survey_id].present?

      render json: {questions: @presenter.questions(params[:survey_id])}, status: :ok and return
    end

    private

    def update_cache(survey, creation_date, created_viewed_impression, created_submission)
      # Have to be careful about creation times and double-counting. If we create submission anytime in the last hour then they may be counted twice
      cache_record = SurveySubmissionCache.find_by(survey: survey, applies_to_date: creation_date)

      if cache_record
        cache_record.increment(:impression_count)
        cache_record.increment(:viewed_impression_count) if created_viewed_impression
        cache_record.increment(:submission_count) if created_submission
        cache_record.save
      else
        SurveySubmissionCache.create(
          survey: survey,
          applies_to_date: creation_date,
          impression_count: 1,
          viewed_impression_count: (created_viewed_impression ? 1 : 0),
          submission_count: (created_submission ? 1 : 0)
        )
      end
    end

    def num_impressions_to_create
      all_submission_params_present? ? params[:num_impressions_to_create].to_i : 1000
    end

    def num_viewed_impressions_to_create
      all_submission_params_present? ? params[:num_viewed_impressions_to_create].to_i : 1000
    end

    def num_submissions_to_create
      all_submission_params_present? ? params[:num_submissions_to_create].to_i : 1000
    end

    def all_submission_params_present?
      params[:num_impressions_to_create].present? && params[:num_viewed_impressions_to_create].present? && params[:num_submissions_to_create].present?
    end

    def choose_completion_url
      params[:completion_urls]&.select(&:present?)&.sample
    end

    def choose_creation_date
      default_date = 1.day.ago.to_date

      start_date = params[:start_date]&.to_date
      end_date = params[:end_date]&.to_date

      if start_date.present? && end_date.present? && start_date <= default_date && end_date <= default_date
        (start_date..end_date).to_a.sample
      else
        default_date
      end
    end

    def generate_answer_to_question(question, submission)
      if question.single_choice_question?
        generate_single_choice_answer(question, submission)
      elsif question.multiple_choices_question?
        generate_multiple_choice_answer(question, submission)
      elsif question.free_text_question?
        generate_free_text_answer(question, submission)
      elsif question.slider_question?
        generate_slider_answer(question, submission)
      end
    end

    def generate_single_choice_answer(question, submission)
      possible_answer = question.possible_answers.sample

      weight_params = params.dig(:possible_answer_weights, question.id.to_s)

      if weight_params.present? && weight_params.all? { |param| param[:possible_answer_id].present? }
        weight_params.each { |param| param[:weight] = param[:weight].to_i }

        chosen_element = weighted_sample(weight_params)
        possible_answer = PossibleAnswer.find(chosen_element[:possible_answer_id])
      end

      question.answers.create(possible_answer: possible_answer, submission: submission, created_at: submission.created_at)
    end
    alias generate_slider_answer generate_single_choice_answer # TODO: Turn slider type into single choice like we do for NPS https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2379

    def generate_multiple_choice_answer(question, submission)
      maximum_selections = question.enable_maximum_selection? ? question.maximum_selection : question.possible_answers.count
      number_to_choose = (1..maximum_selections).to_a.sample

      question.possible_answers.sample(number_to_choose).each do |possible_answer|
        question.answers.create(possible_answer: possible_answer, submission: submission, created_at: submission.created_at)
      end
    end

    def generate_free_text_answer(question, submission)
      answer_keywords = []

      question.update(keyword_extraction: generate_keyword_extractions) if question.keyword_extraction.nil?

      question.keyword_extraction.each_pair do |k, v|
        answer_keywords << { "relevance" => (v.to_f / (k.length ** 2)).to_s, "text" => k }
      end

      question.answers.create(
        text_answer: FFaker::Lorem.phrase, submission: submission,
        created_at: submission.created_at, keyword_extraction: answer_keywords
      )
    end

    def generate_keyword_extractions
      keyword_extraction = {}
      10.times do |_|
        keyword_extraction[FFaker::Lorem.unique.word] = rand(100000) / 10000000.0
      end
      keyword_extraction
    end

    # elements is a Hash
    # each element has :weight key
    # each :weight value is an integer
    # the total of all :weight values is 100
    def weighted_sample(elements)
      raise ArgumentError if elements.any? { |element| element[:weight].negative? || !element[:weight].is_a?(Integer) }

      total = elements.sum { |element| element[:weight] }
      raise ArgumentError if total != 100

      elements.map { |element| [element] * element[:weight] }.flatten.sample
    end

    def set_presenter
      @presenter = SubmissionGeneratorPresenter.new
    end
  end
end
