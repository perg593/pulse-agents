# frozen_string_literal: true

require_relative '../database/pdf_templates/database'
require_relative 's3'

module Rack
  module PdfTemplates
    class FileFetcher
      include Database::PDFTemplates::Database
      include Postgres

      def initialize
        @files = []
      end

      def fetch_files(survey_id)
        # Get URLs of template files
        pdf_template_object_keys = get_survey_pdf_template_object_keys(survey_id)
        log "pdf_template_object_keys: #{pdf_template_object_keys}", "DEBUG"

        key_file_map = pdf_template_object_keys.each_with_object({}) do |key, hash|
          hash[key] = S3.get_template_file_contents(key)
        end

        log "Downloaded from S3 #{key_file_map}", "DEBUG"

        {
          template_file: extract_template_file(key_file_map),
          css_files: extract_css_files(key_file_map),
          image_files: extract_image_files(key_file_map),
          font_files: extract_font_files(key_file_map),
          pdf_files: extract_pdf_files(key_file_map)
        }
      end

      def clean_up_files
        @files.each(&:close)
        log "Cleaning up files #{@files.map(&:path)}", "DEBUG"

        ::File.delete(*@files.map(&:path))
      end

      private

      def extract_template_file(key_file_map)
        template_key = key_file_map.keys.find { |key| key =~ /\.html\.erb$/ }
        log "Detected template file: #{template_key}", "DEBUG"

        return nil unless template_key

        write_temp_file(template_key, key_file_map[template_key])
      end

      def extract_css_files(key_file_map)
        css_keys = key_file_map.keys.grep(/\.css$/)
        log "Detected CSS files: #{css_keys}", "DEBUG"

        css_keys.map do |key|
          write_temp_file(key, key_file_map[key])
        end
      end

      def extract_image_files(key_file_map)
        image_keys = key_file_map.keys.grep(/\.(jpg|jpeg|png|gif|svg)$/)
        log "Detected image files: #{image_keys}", "DEBUG"

        image_keys.map do |key|
          write_temp_file(key, key_file_map[key])
        end
      end

      def extract_pdf_files(key_file_map)
        pdf_keys = key_file_map.keys.grep(/\.pdf$/)
        log "Detected PDF files: #{pdf_keys}.", "DEBUG"

        pdf_keys.map do |key|
          {
            metadata: get_survey_pdf_template_metadata(key),
            file: write_temp_file(key, key_file_map[key])
          }
        end
      end

      def extract_font_files(key_file_map)
        font_keys = key_file_map.keys.grep(/\.(ttf|otf|woff|woff2)$/)
        log "Detected font files: #{font_keys}", "DEBUG"

        font_keys.map do |key|
          write_temp_file(key, key_file_map[key])
        end
      end

      def write_temp_file(object_key, object_content)
        tmp_dir_path = ::File.expand_path("../../tmp/", __dir__)

        # There may be another user requesting the same PDF, so let's add a random subdirectory
        random_subdirectory = SecureRandom.uuid

        # Not using Tempfile because it garbles the filename, which messes up our template's expectations
        path = ::File.expand_path("#{tmp_dir_path}/#{random_subdirectory}/#{object_key}", __FILE__)
        log "Writing #{object_key} to #{path}", "DEBUG"

        # Make all missing parent directories before writing the file
        parent_directories = ::File.dirname(object_key)
        FileUtils.mkdir_p "#{tmp_dir_path}/#{random_subdirectory}/#{parent_directories}/"

        file = ::File.new(path, 'w+')

        file.write(object_content)
        log "Wrote #{object_key} to #{file.path}", "DEBUG"
        file.rewind

        @files << file

        file
      end
    end
  end
end
