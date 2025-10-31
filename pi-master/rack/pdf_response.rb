# frozen_string_literal: true

require 'wicked_pdf'
require 'combine_pdf'

require_relative "database/pdf_templates/database"
require_relative "pdf_templates/pdf_generator"

module Rack
  class PDFResponse
    include Postgres
    include DatabaseGetters
    include Database::PDFTemplates::Database

    # TODO: Establish a connection to database during the initialization phase of the app,
    #       instead of when issuing the first query, if the connection established is kept as long as possible
    def initialize(pg_connection, answer_params)
      @pg_connection = pg_connection # Needed by Postgres, not to establish a connection for every request, with no connection pool in place
      @answer_params = answer_params
    end

    def generate
      survey = get_survey(@answer_params.first["question_id"]).first

      template_submission = get_template_submission(survey["id"])

      # Add selections to template_submission
      @answer_params.each do |answer_param|
        next if %w(free_text_question custom_content_question).include? answer_param["question_type"]

        template_question = template_submission[:questions].find { |question| question[:id] == answer_param["question_id"].to_i }

        template_question[:possible_answers].each do |possible_answer|
          possible_answer[:selected] = answer_param["answer"].include?(possible_answer[:id].to_s)
        end
      end

      pdf = PdfTemplates::PDFGenerator.new.generate(survey['id'].to_i, template_submission)

      log "PDF generated", "DEBUG"

      response = Rack::Response.new(pdf, 200, headers(file_name: "#{survey['name']}.pdf"))

      response.finish
    end

    private

    def headers(file_name:)
      {
        "content-type" => "application/pdf",
        "access-control-allow-origin" => "*",
        "access-control-expose-headers" => "File-Name",
        "file-name" => URI.encode_www_form_component(file_name.gsub(' ', '_')) # User preference for underscores over URL encoded character "+"
      }
    end
  end
end
