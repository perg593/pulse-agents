# frozen_string_literal: true
# !/usr/bin/env ruby

require "erb"
require "json"
require_relative "../../rack/pdf_templates/template_renderer"

module PDFTemplateValidator
  if $PROGRAM_NAME == __FILE__
    template_file_path = ARGV[0]

    if template_file_path.empty?
      exit 1
    end

    puts "Validating #{template_file_path}..."
    template_file = File.new(template_file_path)
    template_renderer = Rack::PdfTemplates::TemplateRenderer.new(template_file)

    begin
      template_renderer.render_template
    rescue NoMethodError, ArgumentError => e
      # This will likely represent imperfect use of answer_info or a missing asset reference
      puts "#{e} -- ignoring"
    rescue SecurityError => _e
      exit 1
    end

    exit 0
  end
end
