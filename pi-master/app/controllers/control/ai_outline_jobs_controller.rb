# frozen_string_literal: true

require_relative "../../../lib/gamma_client/gamma_client"

module Control
  class AIOutlineJobsController < BaseController
    include FiltersHelper
    include RedirectHelper

    before_action :set_survey
    before_action :set_ai_outline_job, only: [:show]
    before_action :require_full_access_user!, only: [:create]
    before_action :validate_generation_id_param, only: [:check_gamma_presentation_status]
    before_action :set_gamma_job, only: [:check_gamma_presentation_status]
    before_action :handle_completed_gamma, only: [:check_gamma_presentation_status]

    def index
      jobs = @survey.ai_outline_jobs.order(created_at: :desc).limit(10)
      render json: jobs.as_json(only: [:id, :status, :created_at])
    end

    def show
      render json: @ai_outline_job.as_json(only: [
                                             :id, :status, :outline_content, :error_message, :created_at, :started_at,
                                             :completed_at, :gamma_generation_id, :gamma_url, :gamma_started_at, :gamma_completed_at
                                           ])
    end

    def create
      # Validate parameters
      unless valid_create_params?
        render json: { error: "Invalid parameters" }, status: :unprocessable_entity
        return
      end

      # Create the job with filters
      job = create_ai_outline_job

      # Enqueue the worker
      AIOutlineWorker.perform_async(job.id)

      render json: { id: job.id, status: job.status }, status: :created
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def generate_gamma_presentation
      return unless validate_gamma_generation_params

      job = find_job_for_gamma_generation
      return if job.nil?

      return if handle_existing_gamma_generation(job)

      start_gamma_generation(job)
    end

    def check_gamma_presentation_status
      check_gamma_status_with_api(@gamma_job, params[:generation_id])
    end

    def download_gamma_presentation
      gamma_url = params[:gamma_url]

      if gamma_url.blank?
        render json: { error: 'Gamma URL is required' }, status: :bad_request
        return
      end

      begin
        # For now, we'll return the URL for the user to download manually
        # In the future, we could implement actual file download logic
        render json: {
          success: true,
          download_url: gamma_url,
          message: 'Please visit the URL to download your presentation'
        }
      rescue => e
        Rails.logger.error("Error handling Gamma download: #{e.message}")
        render json: { error: 'An error occurred while processing the download' }, status: :internal_server_error
      end
    end

    private

    def set_survey
      handle_missing_record unless @survey = current_account.surveys.find_by(id: params[:survey_id])
    end

    def set_ai_outline_job
      handle_missing_record unless @ai_outline_job = @survey.ai_outline_jobs.find_by(id: params[:id])
    end

    def validate_generation_id_param
      return unless params[:generation_id].blank?
      render json: { error: 'Generation ID is required' }, status: :bad_request
      return false # Stop filter chain
    end

    def set_gamma_job
      @gamma_job = @survey.ai_outline_jobs.find_by(gamma_generation_id: params[:generation_id])
      return unless @gamma_job.nil?
      render json: { error: 'Job not found for this generation ID' }, status: :not_found
      return false # Stop filter chain
    end

    def handle_completed_gamma
      return unless @gamma_job&.gamma_ready?

      render json: {
        success: true,
        status: 'completed',
        gamma_url: @gamma_job.gamma_url,
        generation_id: params[:generation_id]
      }
      return false # Stop filter chain
    end

    def ai_outline_job_params
      params.permit(:prompt_template_id, :prompt_text, :use_default_prompt)
    end

    def valid_create_params?
      # Must have either prompt_template_id, prompt_text, or use_default_prompt
      params[:prompt_template_id].present? ||
        params[:prompt_text].present? ||
        params[:use_default_prompt]
    end

    def ai_outline_job_filters
      filters = parse_filters(params)

      device_filter = filters[:device_types] # Same filter, different name

      filters = filters.slice(:date_range, :completion_urls, :pageview_count, :visit_count)
      filters[:device_filter] = device_filter

      filters.compact
    end

    def create_ai_outline_job
      if params[:use_default_prompt]
        # Use default prompt template
        default_template = PromptTemplate.find_by(is_default: true)
        raise "No default prompt template found" unless default_template

        AIOutlineJob.create_for_survey(
          @survey,
          prompt_template: default_template,
          use_default_prompt: true,
          filters: ai_outline_job_filters
        )
      elsif params[:prompt_template_id].present?
        # Use specific prompt template
        prompt_template = PromptTemplate.find(params[:prompt_template_id])

        AIOutlineJob.create_for_survey(
          @survey,
          prompt_template: prompt_template,
          prompt_text: params[:prompt_text],
          filters: ai_outline_job_filters
        )
      else
        # Use custom prompt text
        AIOutlineJob.create_for_survey(
          @survey,
          prompt_text: params[:prompt_text],
          filters: ai_outline_job_filters
        )
      end
    end

    def validate_gamma_generation_params
      if params[:job_id].blank?
        render json: { error: 'Job ID is required' }, status: :bad_request
        return false
      end

      if params[:outline_content].blank?
        render json: { error: 'Outline content is required' }, status: :bad_request
        return false
      end

      true
    end

    def find_job_for_gamma_generation
      @survey.ai_outline_jobs.find(params[:job_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Job not found' }, status: :not_found
      nil
    end

    def handle_existing_gamma_generation(job)
      if job.gamma_processing?
        render json: {
          success: true,
          generation_id: job.gamma_generation_id,
          message: 'Gamma presentation generation already in progress'
        }
        return true
      end

      if job.gamma_ready?
        render json: {
          success: true,
          generation_id: job.gamma_generation_id,
          gamma_url: job.gamma_url,
          message: 'Gamma presentation already completed'
        }
        return true
      end

      false
    end

    def start_gamma_generation(job)
      generation_id = generate_gamma_id(job)
      unless generation_id
        error_message = @gamma_error || 'Failed to start Gamma generation'
        status_code = @gamma_error_type == :unexpected ? :internal_server_error : :unprocessable_entity
        render json: { error: error_message }, status: status_code
        return
      end

      update_job_and_start_generation(job, generation_id)
    end

    def generate_gamma_id(_job)
      if Rails.env.development?
        "dev_mock_#{SecureRandom.hex(8)}"
      else
        GammaClient.generate_gamma(input_text: params[:outline_content])
      end
    rescue GammaClient::HTTP::GammaError => e
      Rails.logger.error("Gamma API error: #{e.message}")
      @gamma_error = "Gamma generation failed: #{e.message}"
      @gamma_error_type = :api
      nil
    rescue => e
      Rails.logger.error("Unexpected error generating Gamma presentation: #{e.message}")
      @gamma_error = 'An unexpected error occurred while generating the presentation'
      @gamma_error_type = :unexpected
      nil
    end

    def update_job_and_start_generation(job, generation_id)
      job.update!(outline_content: params[:outline_content])
      job.start_gamma_generation!(generation_id)

      render json: {
        success: true,
        generation_id: generation_id,
        message: 'Gamma presentation generation started'
      }
    end

    def check_gamma_status_with_api(job, generation_id)
      result = get_gamma_status_result(job, generation_id)
      unless result
        error_message = @gamma_status_error || 'Failed to check Gamma presentation status'
        status_code = @gamma_status_error_type == :unexpected ? :internal_server_error : :unprocessable_entity
        render json: { error: error_message }, status: status_code
        return
      end

      update_job_from_gamma_result(job, result)
      render_gamma_status_response(result, generation_id)
    end

    def get_gamma_status_result(job, generation_id)
      if Rails.env.development? && generation_id.start_with?('dev_mock_')
        {
          'status' => 'completed',
          'gammaUrl' => 'https://gamma.app/docs/dev-mock-presentation',
          'generationId' => generation_id
        }
      else
        GammaClient.get_generation_status(generation_id)
      end
    rescue GammaClient::HTTP::GammaError => e
      Rails.logger.error("Gamma API error: #{e.message}")
      job&.fail_gamma_generation!(e.message)
      @gamma_status_error = "Failed to check status: #{e.message}"
      @gamma_status_error_type = :api
      nil
    rescue => e
      Rails.logger.error("Unexpected error checking Gamma presentation status: #{e.message}")
      job&.fail_gamma_generation!(e.message)
      @gamma_status_error = 'An unexpected error occurred while checking status'
      @gamma_status_error_type = :unexpected
      nil
    end

    def update_job_from_gamma_result(job, result)
      case result['status']
      when 'completed'
        job.complete_gamma_generation!(result['gammaUrl']) if result['gammaUrl'].present?
      when 'failed'
        job.fail_gamma_generation!('Gamma generation failed')
      end
    end

    def render_gamma_status_response(result, generation_id)
      render json: {
        success: true,
        status: result['status'],
        gamma_url: result['gammaUrl'],
        generation_id: generation_id
      }
    end
  end
end
