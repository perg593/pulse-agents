# frozen_string_literal: true
module Admin
  class SurveysController < BaseController
    before_action :set_survey

    def metadata
      @presenter = SurveyMetadataPresenter.new(@survey)
    end

    def pdf_template
      flash.now.alert = "Survey not found. Missing survey_id?" and return unless @survey.present?
      flash.now.alert = "Survey metadata not found. Please assign it" and return unless @survey.metadatum.present?

      @presenter = PDFTemplatePresenter.new(@survey)
    end

    def troubleshoot
      flash.now.alert = "Survey with ID #{params[:survey_id]} not found" and return if params[:survey_id] && @survey.nil?

      flash.now.alert = "Invalid URL #{params[:url]}" unless params[:url].blank? || valid_url?

      url = valid_url? ? params[:url] : nil

      @presenter = SurveyTroubleshooterPresenter.new(@survey, params[:device_udid], url)
    end

    # Note that we're not cleaning up the files written to disk.
    # We need to keep them around so that they can be loaded by the
    # browser when it opens the HTML file.
    def html_preview
      file_fetcher = Rack::PdfTemplates::FileFetcher.new
      files_by_type = file_fetcher.fetch_files(@survey.id)

      renderer = Rack::PdfTemplates::TemplateRenderer.new(
        files_by_type[:template_file],
        css_files: files_by_type[:css_files],
        image_files: files_by_type[:image_files],
        font_files: files_by_type[:font_files],
        answer_info: generate_sample_info
      )

      rendered_template = renderer.render_template

      send_data rendered_template, filename: "preview.html", type: "text/html"
    rescue ArgumentError => e
      flash.alert = e

      redirect_to pdf_template_admin_surveys_path(survey_id: params[:survey_id])
    end

    def preview
      answer_options = generate_sample_info

      pdf = Rack::PdfTemplates::PDFGenerator.new.generate(@survey.id, answer_options)

      send_data pdf, filename: "#{@survey.metadatum.name}_preview.pdf", type: "application/pdf"
    rescue ArgumentError => e
      flash.alert = e

      redirect_to pdf_template_admin_surveys_path(survey_id: params[:survey_id])
    end

    private

    def generate_sample_info
      template_questions = @survey.questions.map do |question|
        template_possible_answers = question.possible_answers.map do |possible_answer|
          {
            id: possible_answer.id,
            metaname: possible_answer.metadatum.name,
            content: possible_answer.content,
            selected: [true, false].sample
          }
        end

        {
          id: question.id,
          metaname: question.metadatum.name,
          content: question.content,
          type: question.question_type,
          possible_answers: template_possible_answers
        }
      end

      {
        questions: template_questions
      }
    end

    def valid_url?
      return false if params[:url].blank?

      uri = URI.parse(params[:url])
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    end

    def set_survey
      @survey = Survey.find_by(id: params[:survey_id])
    end
  end
end
