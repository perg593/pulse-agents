# frozen_string_literal: true

require 'google/apis/drive_v3'
require 'google/apis/slides_v1'
require 'googleauth'
require 'open-uri'
require_relative 'google_slides_navigator'
require_relative 'google_slides_request_builder'
require_relative 'google_drive_file_manager'

module Google
  class SurveyOverviewPresentationService
    class SlideNotFoundError < StandardError; end
    class ElementNotFoundError < StandardError; end

    include Google::GoogleSlidesNavigator

    attr_reader :drive_service, :slides_service

    SCOPES = [
      Google::Apis::DriveV3::AUTH_DRIVE,
      Google::Apis::SlidesV1::AUTH_PRESENTATIONS
    ].freeze

    TARGET_URL_TEMPLATE_COLORS = { red: 0.533, green: 0.518, blue: 0.612 }.freeze

    CANVAS_SLIDE_IDENTIFIER_TEXT = "CANVAS_SLIDE"
    DESKTOP_IN_SITU_SLIDE_IDENTIFIER_TEXT = "IN-SITU SLIDE: DESKTOP"
    MOBILE_IN_SITU_SLIDE_IDENTIFIER_TEXT = "IN-SITU SLIDE: MOBILE"
    BRIEF_SLIDE_IDENTIFIER_TEXT = "SURVEY_BRIEF_SLIDE"

    # Initialize the Google Drive and Slides services with authentication
    # @return [Google::SurveyOverviewPresentationService] A new instance of SurveyOverviewPresentationService
    # @raise [StandardError] If initialization fails
    def initialize
      Rails.logger.info("Initializing Google::SurveyOverviewPresentationService")

      # Set up authentication using Application Default Credentials (ADC)
      auth = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(service_account_credentials.to_json),
        scope: SCOPES
      )

      # Initialize Drive service with authentication
      @drive_service = Google::Apis::DriveV3::DriveService.new
      @drive_service.authorization = auth

      # Initialize Slides service with authentication
      @slides_service = Google::Apis::SlidesV1::SlidesService.new
      @slides_service.authorization = auth

      # Initialize file manager and request builder
      @file_manager = Google::GoogleDriveFileManager.new(@drive_service, @slides_service)
      @request_builder = Google::GoogleSlidesRequestBuilder.new

      Rails.logger.info("Google::SurveyOverviewPresentationService initialized successfully")
    rescue StandardError => e
      Rails.logger.error("Failed to initialize Google::SurveyOverviewPresentationService: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    # Copy a Google Drive file
    # @param file_id [String] The ID of the file to copy
    # @param name [String] The name for the copied file
    # @return [Google::Apis::DriveV3::File] The copied file
    # @raise [StandardError] If the copy operation fails
    def copy_file(file_id, name)
      @file_manager.copy_file(file_id, name)
    end

    # Share a Google Drive file with organization-wide access
    # @param file_id [String] The ID of the file to share
    # @return [Google::Apis::DriveV3::Permission] The created permission
    # @raise [StandardError] If the share operation fails
    def share_file_with_organization(file_id)
      @file_manager.share_file_with_organization(file_id)
    end

    # Replace text placeholders in a Google Slides presentation
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param data [Hash] A hash of placeholder keys and their replacement values
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse, nil] The response from the API or nil if no replacements needed
    # @raise [StandardError] If the replacement operation fails
    def replace_text_placeholders(google_presentation_id, data)
      Rails.logger.info("Replacing text placeholders in presentation #{google_presentation_id}")
      Rails.logger.info("Placeholder data: #{data.inspect}")

      return nil if data.empty?

      requests = data.map do |key, value|
        {
          replace_all_text: {
            contains_text: {
              text: "{{#{key}}}",
                match_case: true
            },
            replace_text: value.to_s
          }
        }
      end

      response = @file_manager.execute_batch_requests(google_presentation_id, requests, operation: "replace text placeholders")

      Rails.logger.info("Successfully replaced text placeholders")
      response
    rescue StandardError => e
      Rails.logger.error("Failed to replace text placeholders: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      raise
    end

    # Remove the survey brief slide identifier text
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [SlideNotFoundError] If the brief slide cannot be found
    # @raise [StandardError] If the removal operation fails
    def remove_survey_brief_slide_identifier(google_presentation_id)
      presentation = @file_manager.get_presentation(google_presentation_id)
      brief_slide = find_slide_with_text(presentation, BRIEF_SLIDE_IDENTIFIER_TEXT)
      raise SlideNotFoundError, "Could not find brief slide with identifier: #{BRIEF_SLIDE_IDENTIFIER_TEXT}" unless brief_slide

      cleanup_request = build_cleanup_slide_request(brief_slide, BRIEF_SLIDE_IDENTIFIER_TEXT)

      @file_manager.execute_request(google_presentation_id, cleanup_request, operation: "clean up survey brief slide")
    end

    # Remove the survey brief slide from the presentation
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [SlideNotFoundError] If the brief slide cannot be found
    # @raise [StandardError] If the removal operation fails
    def remove_survey_brief_slide(google_presentation_id)
      presentation = @file_manager.get_presentation(google_presentation_id)
      brief_slide = find_slide_with_text(presentation, BRIEF_SLIDE_IDENTIFIER_TEXT)
      raise SlideNotFoundError, "Could not find brief slide with identifier: #{BRIEF_SLIDE_IDENTIFIER_TEXT}" unless brief_slide
      brief_slide_id = brief_slide.object_id_prop
      request = @request_builder.build_delete_object_request(brief_slide_id)

      @file_manager.execute_request(google_presentation_id, request, operation: "Brief slide removal")
    end

    # Replace custom content link box content in the canvas slide
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param custom_content_data [Hash] Hash containing card names and their associated links
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [ElementNotFoundError] If the custom content link box element cannot be found
    # @raise [StandardError] If the replacement operation fails
    def replace_custom_content_link_box_content(google_presentation_id, custom_content_data)
      Rails.logger.info("Replacing custom content link box content in presentation #{google_presentation_id}")

      presentation = @file_manager.get_presentation(google_presentation_id)
      canvas_slide = find_slide_with_text(presentation, CANVAS_SLIDE_IDENTIFIER_TEXT)
      raise SlideNotFoundError, "Could not find canvas slide with identifier: #{CANVAS_SLIDE_IDENTIFIER_TEXT}" unless canvas_slide

      text_element = find_text_element_with_description(canvas_slide, "custom_content_link_box")
      raise ElementNotFoundError, "Could not find custom content link box element" unless text_element

      formatted_text = formatted_custom_content_data(custom_content_data)

      requests = []
      requests << @request_builder.build_delete_text_request(text_element.object_id_prop)
      requests << @request_builder.build_insert_text_request(text_element.object_id_prop, formatted_text)

      @file_manager.execute_batch_requests(google_presentation_id, requests, operation: "custom content link box content replacement")
    rescue StandardError => e
      Rails.logger.error("Failed to replace custom content link box content: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    # Replace the canvas slide image and remove its identifier text box
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param survey_editor_screenshot [CarrierWave::Uploader::Base] The survey editor screenshot uploader
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [SlideNotFoundError] If the canvas slide cannot be found
    # @raise [ElementNotFoundError] If the image element cannot be found
    # @raise [StandardError] If the replacement operation fails
    def replace_canvas_slide_image(google_presentation_id, survey_editor_screenshot)
      Rails.logger.info("Replacing canvas slide image in presentation #{google_presentation_id}")

      presentation = @file_manager.get_presentation(google_presentation_id)
      canvas_slide = find_slide_with_text(presentation, CANVAS_SLIDE_IDENTIFIER_TEXT)
      raise SlideNotFoundError, "Could not find canvas slide with identifier: #{CANVAS_SLIDE_IDENTIFIER_TEXT}" unless canvas_slide
      canvas_slide_id = canvas_slide.object_id_prop

      Rails.logger.info("Found canvas slide with ID: #{canvas_slide_id}")

      image_url = survey_editor_screenshot.url
      Rails.logger.info("Generated presigned URL: #{image_url}")

      image_element = find_image_element_with_description(canvas_slide, "canvas_screenshot")
      raise ElementNotFoundError, "Could not find image element with description: canvas_screenshot" unless image_element
      Rails.logger.info("Found image element with ID: #{image_element.object_id_prop}")

      requests = []
      requests << build_replace_screenshot_request(canvas_slide, "canvas_screenshot", image_url)
      requests << build_cleanup_slide_request(canvas_slide, CANVAS_SLIDE_IDENTIFIER_TEXT)

      Rails.logger.info("Created canvas requests: #{requests.inspect}")

      @file_manager.execute_batch_requests(google_presentation_id, requests, operation: "canvas slide image replacement")
    rescue StandardError => e
      Rails.logger.error("Failed to replace canvas slide image: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    # Replace client page screenshots in a Google Slides presentation
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param client_page_screenshots_desktop [Array<CarrierWave::Uploader::Base>] Array of desktop client page screenshot uploaders
    # @param client_page_screenshots_mobile [Array<CarrierWave::Uploader::Base>] Array of mobile client page screenshot uploaders
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [SlideNotFoundError] If the template slides cannot be found
    # @raise [StandardError] If the replacement operation fails
    def replace_client_page_screenshots(google_presentation_id, client_page_screenshots_desktop, client_page_screenshots_mobile)
      Rails.logger.info("Replacing client page screenshots in presentation #{google_presentation_id}")
      Rails.logger.info("Number of desktop screenshots to process: #{client_page_screenshots_desktop.length}")
      Rails.logger.info("Number of mobile screenshots to process: #{client_page_screenshots_mobile.length}")

      presentation = @file_manager.get_presentation(google_presentation_id)

      desktop_template_slide = find_slide_with_text(presentation, DESKTOP_IN_SITU_SLIDE_IDENTIFIER_TEXT)
      raise SlideNotFoundError, "Could not find desktop template slide with identifier: #{DESKTOP_IN_SITU_SLIDE_IDENTIFIER_TEXT}" unless desktop_template_slide
      desktop_template_slide_id = desktop_template_slide.object_id_prop

      mobile_template_slide = find_slide_with_text(presentation, MOBILE_IN_SITU_SLIDE_IDENTIFIER_TEXT)
      raise SlideNotFoundError, "Could not find mobile template slide with identifier: #{MOBILE_IN_SITU_SLIDE_IDENTIFIER_TEXT}" unless mobile_template_slide
      mobile_template_slide_id = mobile_template_slide.object_id_prop

      Rails.logger.info("Found desktop template slide with ID: #{desktop_template_slide_id}")
      Rails.logger.info("Found mobile template slide with ID: #{mobile_template_slide_id}")

      desktop_duplicate_requests = build_duplicate_slide_requests(desktop_template_slide_id, client_page_screenshots_desktop)
      mobile_duplicate_requests = build_duplicate_slide_requests(mobile_template_slide_id, client_page_screenshots_mobile)

      response = @file_manager.execute_batch_requests(google_presentation_id, desktop_duplicate_requests + mobile_duplicate_requests,
                                                      operation: "slide duplication")

      overwrite_in_situ_screenshots(google_presentation_id, desktop_template_slide_id, client_page_screenshots_desktop, "desktop_screenshot")
      overwrite_in_situ_screenshots(google_presentation_id, mobile_template_slide_id, client_page_screenshots_mobile, "mobile_screenshot")

      response
    rescue StandardError => e
      Rails.logger.error("Failed to replace client page screenshots: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    # Replace trigger URLs content in the presentation
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param header_url_pairs [Array<Array<String>>] Array of [header, url] pairs to insert
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [ElementNotFoundError] If the target URL template cell cannot be found
    # @raise [StandardError] If the replacement operation fails
    def replace_trigger_urls_content(google_presentation_id, trigger_type_url_pairs)
      replace_cell_content(
        google_presentation_id,
        trigger_type_url_pairs,
        "target_url_template",
        "trigger URLs content replacement"
      )
    end

    # Replace suppressed URLs content in the presentation
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param header_url_pairs [Array<Array<String>>] Array of [header, url] pairs to insert
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [ElementNotFoundError] If the suppressed URL cell cannot be found
    # @raise [StandardError] If the replacement operation fails
    def replace_suppressed_urls_content(google_presentation_id, trigger_type_url_pairs)
      replace_cell_content(
        google_presentation_id,
        trigger_type_url_pairs,
        "suppressed_url",
        "suppressed URLs content replacement"
      )
    end

    private

    # Create requests to duplicate a template slide
    # @param template_slide_id [String] The ID of the template slide to duplicate
    # @param client_page_screenshots [Array<CarrierWave::Uploader::Base>] Array of screenshot uploaders
    # @return [Array<Hash>] Array of duplicate object requests
    def build_duplicate_slide_requests(template_slide_id, client_page_screenshots)
      # Get the objectId from the slide's properties
      Rails.logger.info("Template slide object ID: #{template_slide_id}")

      requests = []
      # For each screenshot after the first one, duplicate the template slide
      (client_page_screenshots.length - 1).times do
        requests << @request_builder.build_duplicate_object_request(template_slide_id)
      end

      requests
    end

    # Overwrite in-situ screenshots in the presentation
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param template_slide_id [String] The ID of the template slide
    # @param client_page_screenshots [Array<CarrierWave::Uploader::Base>] Array of screenshot uploaders
    # @param image_description [String] Description of the image element to replace
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [StandardError] If the screenshot replacement fails
    def overwrite_in_situ_screenshots(google_presentation_id, template_slide_id, client_page_screenshots, image_description)
      # Reload the presentation after duplicating slides to get updated element IDs
      updated_presentation = @file_manager.get_presentation(google_presentation_id)

      # Get the template slide's ID
      Rails.logger.info("Template slide ID: #{template_slide_id}")

      # Find the index of the template slide using its actual object ID
      template_slide_index = updated_presentation.slides.find_index { |slide| slide.object_id_prop == template_slide_id }
      Rails.logger.info("Template slide index: #{template_slide_index}")

      # Get the slides that come after the template slide
      slides_to_update = updated_presentation.slides[template_slide_index, client_page_screenshots.length] || []
      Rails.logger.info("Found #{slides_to_update.length} slides to update with screenshots")

      # Create requests for both image replacement and text deletion
      image_requests = []
      slides_to_update.each_with_index do |slide, index|
        image_url = client_page_screenshots[index].url

        # Find and delete the identifier text element
        identifier_text = image_description == "desktop_screenshot" ? DESKTOP_IN_SITU_SLIDE_IDENTIFIER_TEXT : MOBILE_IN_SITU_SLIDE_IDENTIFIER_TEXT

        image_requests << build_replace_screenshot_request(slide, image_description, image_url)
        image_requests << build_cleanup_slide_request(slide, identifier_text)
      end

      return if image_requests.empty?

      @file_manager.execute_batch_requests(google_presentation_id, image_requests, operation: "screenshot updates")
    end

    # Replace content in a table cell
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param header_url_pairs [Array<Array<String>>] Array of [header, url] pairs to insert
    # @param placeholder_text [String] The placeholder text to search for
    # @param operation_name [String] Description of the operation being performed
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [ElementNotFoundError] If the table or cell cannot be found
    # @raise [StandardError] If the replacement operation fails
    def replace_cell_content(google_presentation_id, header_url_pairs, placeholder_text, operation_name)
      Rails.logger.info("Replacing #{operation_name} in presentation #{google_presentation_id}")

      presentation = @file_manager.get_presentation(google_presentation_id)
      slide = find_slide_with_text(presentation, placeholder_text)
      raise SlideNotFoundError, "Could not find slide with placeholder: #{placeholder_text}" unless slide
      table_element = find_table_element(slide)
      raise ElementNotFoundError, "Could not find table element in slide with placeholder: #{placeholder_text}" unless table_element
      cell = find_cell_with_text(table_element.table, placeholder_text)
      raise ElementNotFoundError, "Could not find cell with placeholder: #{placeholder_text}" unless cell
      cell_location = get_cell_location(table_element, cell)

      header_formatting, url_formatting = cache_formatting_from_template(cell, placeholder_text)
      formatted_content = format_content_with_styles(header_url_pairs, header_formatting, url_formatting)

      requests = build_replacement_requests(table_element, cell_location, formatted_content)
      @file_manager.execute_batch_requests(google_presentation_id, requests, operation: operation_name) unless requests.empty?
    rescue StandardError => e
      Rails.logger.error("Failed to replace #{operation_name}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    # Cache formatting from a template cell
    # @param cell [Google::Apis::SlidesV1::TableCell] The template cell
    # @param placeholder_text [String] The placeholder text to search for
    # @return [Array<Hash>] Array containing header_formatting and url_formatting
    # @raise [ElementNotFoundError] If both header and URL formatting cannot be found
    def cache_formatting_from_template(cell, placeholder_text)
      header_formatting = nil
      url_formatting = nil

      cell.text.text_elements.each do |text_element|
        next unless text_element.text_run
        content = text_element.text_run.content

        if content.include?("{{header_template}}")
          header_formatting = text_element.text_run.style
          Rails.logger.info("Header formatting: #{header_formatting.inspect}")
        elsif content.include?("{{#{placeholder_text}}}")
          url_formatting = text_element.text_run.style
          Rails.logger.info("URL formatting: #{url_formatting.inspect}")
        end
      end

      raise ElementNotFoundError, "Could not find both header and URL formatting" unless header_formatting && url_formatting
      [header_formatting, url_formatting]
    end

    # Format content with styles
    # @param header_url_pairs [Array<Array<String>>] Array of [header, url] pairs
    # @param header_formatting [Hash] The formatting for headers
    # @param url_formatting [Hash] The formatting for URLs
    # @return [Array<Hash>] Array of formatted content objects
    def format_content_with_styles(header_url_pairs, header_formatting, url_formatting)
      header_url_pairs.map do |header, url|
        [
          {
            text: header,
            style: header_formatting
          },
          {
            text: url,
            style: url_formatting
          }
        ]
      end.flatten
    end

    # Build replacement requests for a table cell
    # @param table_element [Google::Apis::SlidesV1::PageElement] The table element
    # @param cell_location [Hash] The location of the cell
    # @param formatted_content [Array<Hash>] The formatted content to insert
    # @return [Array<Hash>] Array of replacement requests
    def build_replacement_requests(table_element, cell_location, formatted_content)
      requests = []

      # First delete all existing text
      requests << @request_builder.build_delete_cell_text_request(table_element.object_id_prop, cell_location)

      # Then insert each piece with its appropriate formatting
      insertion_index = 0
      formatted_content.each_with_index do |content, index|
        style = content[:style]
        text = content[:text]

        Rails.logger.info("Applying style for '#{text}': #{style.inspect}")

        requests << @request_builder.build_insert_cell_text_request(table_element.object_id_prop, cell_location, insertion_index, text)
        requests << @request_builder.build_update_style_request(
          table_element: table_element,
          cell_location: cell_location,
          insertion_index: insertion_index,
          text: text,
          style: style,
          content_index: index
        )

        insertion_index += text.length + 1 # +1 for the newline
      end

      requests
    end

    # Format custom content data for display
    # @param custom_content_data [Hash] Hash containing card names and their associated links
    # @return [String] Formatted text content
    def formatted_custom_content_data(custom_content_data)
      custom_content_data.map do |card_name, links|
        next if links.empty? # Skip questions with no links

        [
          "#{card_name} has the following links:",
          *links.map { |link| "#{link[:text]} links to: #{link[:url]}" }
        ]
      end.compact.flatten.join("\n\n")
    end

    # Build request to delete text element used to identify the slide (metadata, basically)
    # @param slide [Google::Apis::SlidesV1::Page] The slide containing the text element
    # @param slide_identifier_text [String] The text to search for
    # @return [Hash] The delete object request
    def build_cleanup_slide_request(slide, slide_identifier_text)
      text_element = find_text_element_in_slide(slide, slide_identifier_text)

      @request_builder.build_delete_object_request(text_element.object_id_prop)
    end

    # Build request to replace the image
    # @param slide [Google::Apis::SlidesV1::Page] The slide containing the image
    # @param image_element_description [String] The description of the image element
    # @param image_url [String] The URL of the new image
    # @return [Hash] The replace image request
    def build_replace_screenshot_request(slide, image_element_description, image_url)
      image_element = find_image_element_with_description(slide, image_element_description)
      Rails.logger.info("Found image element with ID: #{image_element.object_id_prop}")

      # TODO: Handle failure to find image element
      image_object_id = image_element.object_id_prop

      @request_builder.build_replace_image_request(image_object_id, image_url)
    end

    def service_account_credentials
      credentials = Rails.application.credentials.google_drive

      {
        type: 'service_account',
        project_id: credentials[:project_id],
        private_key_id: credentials[:private_key_id],
        private_key: credentials[:private_key],
        client_email: credentials[:client_email],
        client_id: credentials[:client_id],
        auth_uri: 'https://accounts.google.com/o/oauth2/auth',
        token_uri: 'https://oauth2.googleapis.com/token',
        auth_provider_x509_cert_url: 'https://www.googleapis.com/oauth2/v1/certs',
        client_x509_cert_url: credentials[:client_x509_cert_url],
        universe_domain: 'googleapis.com'
      }
    end
  end
end
