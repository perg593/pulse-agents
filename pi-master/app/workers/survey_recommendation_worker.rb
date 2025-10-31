# frozen_string_literal: true

class SurveyRecommendationWorker
  include Sidekiq::Worker
  include Common
  include Control::FiltersHelper

  sidekiq_options queue: :console

  MAX_FREE_TEXT_RESPONSES = 100

  def perform(survey_id, unparsed_filters = {})
    tagged_logger.info "Started generating recommendations for survey #{survey_id}"

    survey = Survey.find(survey_id)
    filters = parse_filters(unparsed_filters.deep_symbolize_keys)

    response = GPT.chat(prompt(survey, filters))
    raise StandardError, response["error"] if response["error"].present?

    recommendation = survey.recommendations.create!(
      content: JSON.parse(response["choices"][0]["message"]["content"]),
      filters: unparsed_filters
    )

    ActionCable.server.broadcast("survey_recommendations_#{survey_id}", recommendation.as_json(only: %i(id content filters created_at)))

    tagged_logger.info "Successfully generated recommendations for survey #{survey_id}"
  rescue StandardError => e
    ActionCable.server.broadcast("survey_recommendations_#{survey_id}", e.message)

    Rollbar.error(e, survey_id: survey_id, filters: unparsed_filters)

    tagged_logger.error e.full_message
  end

  private

  def prompt(survey, filters)
    "#{base_prompt}\n#{JSON.pretty_generate(survey_data(survey, filters))}"
  end

  def base_prompt
    <<~PROMPT
      Based on the following survey data, recommend 6 questions you'd want to learn next. Be sure to only learn things where the results will be actionable by a Digital Marketing team.

      Use the following output format exactly. Do not return invalid JSON, do not alter the format, and do not wrap the output in backticks or code blocks.

      [
        {
          "title": "Title of this next learning",
          "reasoning": "Because users said X, consider next learning Y.",
          "question": "Proposed survey question",
          "possibleAnswers": ["Answer 1", "Answer 2", "Answer 3"],
          "targeting": "Proposed targeting (which pages on site and which audiences to ask)",
          "expectedBenefit": "Expected Benefit (how this learning will drive the client's goals and project brief)"
        },
        ...
      ]

      Here is the survey data.
    PROMPT
  end

  def survey_data(survey, filters)
    {
      account_name: survey.account.name,
      survey: {
        name: survey.name,
        targeting: targeting_settings(survey)
      },
      questions: fixed_response_distributions(survey, filters) + free_text_response_details(survey, filters)
    }
  end

  def fixed_response_distributions(survey, filters)
    survey.questions.includes(:possible_answers).where(question_type: %i(single_choice_question multiple_choices_question slider_question)).map do |question|
      response_distribution = question.answer_rates(filters: filters).map do |rate|
        {
          response: rate[:possible_answer].content,
          count: rate[:answers_count],
          percentage: (rate[:answer_rate] * 100).round
        }
      end

      {
        question: question.content,
        total_responses: question.answers_count(filters: filters),
        response_distribution: response_distribution
      }
    end
  end

  def free_text_response_details(survey, filters)
    survey.questions.includes(:answers).free_text_question.map do |question|
      response_details = Answer.filtered_answers(question.answers, filters: filters).limit(MAX_FREE_TEXT_RESPONSES).map do |answer|
        {
          response: answer.text_answer,
          device_type: answer.submission.device_type,
          completion_url: answer.submission.url
        }
      end

      {
        question: question.content,
        responses: response_details
      }
    end
  end

  def targeting_settings(survey)
    targeting = {}

    targeting[:sample_rate] = survey.sample_rate

    targeting[:devices] = {
      desktop: survey.desktop_enabled?,
      tablet: survey.tablet_enabled?,
      mobile: survey.mobile_enabled?,
      ios: survey.ios_enabled?,
      android: survey.android_enabled?,
      email: survey.email_enabled?
    }

    targeting[:urls] = survey.triggers.map do |trigger|
      {
        url: trigger.trigger_content,
        excluded: trigger.excluded
      }
    end

    targeting
  end
end
