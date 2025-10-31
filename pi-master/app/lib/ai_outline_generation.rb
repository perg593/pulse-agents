# frozen_string_literal: true

require "logging"
require 'tiktoken_ruby'
require_relative 'claude'
require_relative 'ai_outline_generation/data_providers'
require_relative 'ai_outline_generation/data_providers/survey_data_provider'
require_relative 'ai_outline_generation/data_providers/ai_analysis_provider'
require_relative 'ai_outline_generation/data_providers/device_data_provider'
require_relative 'ai_outline_generation/data_collector'

module AIOutlineGeneration
  MAX_OUTLINE_TOKENS = 4000

  def self.generate_outline(job)
    Generator.new.generate_outline(job)
  end

  # Struct for holding template variables
  TemplateVars = Struct.new(:prompt_text, :survey, :survey_data, :ai_analysis_data, :questions_data, :device_summary, keyword_init: true)

  class Generator
    include Logging
    include SQLHelpers

    def generate_outline(job)
      start_time = Time.current
      tagged_logger.info "Started AI outline generation for job #{job.id}"

      # Use data collector to gather all data
      data_collector = DataCollector.new(job)
      survey_data = data_collector.survey_data
      ai_analysis_data = data_collector.ai_analysis_data
      device_data = data_collector.device_data

      # Build the prompt
      prompt = build_prompt(job, survey_data, ai_analysis_data, device_data)

      tagged_logger.info "Generated prompt with #{Claude.token_count(prompt)} tokens"

      # Check token limits
      if Claude.prompt_exceeds_limit?(prompt)
        tagged_logger.warn "Prompt exceeds token limit, truncating data"
        prompt = truncate_prompt(job, survey_data, ai_analysis_data)
      end

      tagged_logger.info "Prompt: #{prompt}"

      # Generate outline using AI
      response = request_outline(prompt)

      tagged_logger.info "Finished AI outline generation in #{Time.current - start_time}s"

      response
    end

    private

    def build_prompt(job, survey_data, ai_analysis_data, device_data)
      # Prepare template variables
      template_vars = prepare_template_variables(job, survey_data, ai_analysis_data, device_data)

      # Render the ERB template
      template_path = Rails.root.join('app', 'views', 'ai_outline_generation', 'prompt_template.erb')
      template_content = File.read(template_path)

      erb = ERB.new(template_content, trim_mode: '-')
      erb.result(template_vars.instance_eval { binding })
    end

    def prepare_template_variables(job, survey_data, ai_analysis_data, device_data)
      survey = job.survey

      # Prepare prompt text
      prompt_text = job.prompt_text || job.prompt_template&.content || "Generate a comprehensive survey analysis report"

      # Create a simple object to hold template variables
      TemplateVars.new(
        prompt_text: prompt_text,
        survey: survey,
        survey_data: survey_data,
        ai_analysis_data: ai_analysis_data,
        questions_data: device_data[:questions_data],
        device_summary: device_data[:device_summary]
      )
    end

    def truncate_prompt(job, survey_data, ai_analysis_data)
      # Simple truncation strategy - reduce device data
      survey_data[:devices_data] = survey_data[:devices_data].first(3)

      # Rebuild device data with truncated survey data
      truncated_device_data = DataProviders::DeviceDataProvider.new(job, survey_data).call

      build_prompt(job, survey_data, ai_analysis_data, truncated_device_data)
    end

    def request_outline(prompt)
      if Rails.env.development?
        # Development placeholder to avoid costly API calls
        <<~OUTLINE
          # Survey Analysis Report (Development Mode)

          ## Executive Summary
          This is a development placeholder for AI-generated survey analysis. In production, this would contain real AI-generated insights based on the survey data.

          ## Key Findings
          - Development mode: No real analysis performed
          - API calls disabled to avoid costs
          - Real implementation would analyze #{prompt.length} characters of prompt data

          ## Next Steps
          - Deploy to production for real AI analysis
          - Review token usage and optimize as needed
        OUTLINE
      else
        api_call_start_time = Time.current

        response = Claude.chat(prompt, max_tokens: MAX_OUTLINE_TOKENS)

        api_call_duration = Time.current - api_call_start_time
        tagged_logger.info "API call took #{api_call_duration} #{'second'.pluralize(api_call_duration)}"

        if response["error"].present?
          raise StandardError, "AI API error: #{response['error']}"
        end

        response["choices"][0]["message"]["content"]
      end
    end
  end
end
