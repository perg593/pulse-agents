# frozen_string_literal: true

module Google
  class GoogleDriveFileManager
    attr_reader :drive_service, :slides_service

    def initialize(drive_service, slides_service)
      @drive_service = drive_service
      @slides_service = slides_service
    end

    # Copy a Google Drive file
    # @param file_id [String] The ID of the file to copy
    # @param name [String] The name for the copied file
    # @return [Google::Apis::DriveV3::File] The copied file
    # @raise [StandardError] If the copy operation fails
    def copy_file(file_id, name)
      Rails.logger.info("Copying file #{file_id} with new name: #{name}")

      file_metadata = { name: name }
      copied_file = drive_service.copy_file(file_id, file_metadata, fields: 'id')

      Rails.logger.info("Successfully copied file to ID: #{copied_file.id}")

      copied_file
    rescue StandardError => e
      Rails.logger.error("Failed to copy file: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    # Share a Google Drive file with organization-wide access
    # @param file_id [String] The ID of the file to share
    # @return [Google::Apis::DriveV3::Permission] The created permission
    # @raise [StandardError] If the share operation fails
    def share_file_with_organization(file_id)
      Rails.logger.info("Sharing file #{file_id} with organization")

      permission = Google::Apis::DriveV3::Permission.new(
        type: 'domain',
        role: 'writer',
        domain: 'pulseinsights.com',
        allow_file_discovery: true
      )

      result = drive_service.create_permission(
        file_id,
        permission,
        fields: 'id',
        send_notification_email: false
      )

      Rails.logger.info("Successfully shared file #{file_id} with organization")

      result
    rescue StandardError => e
      Rails.logger.error("Failed to share file: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    # Get a Google Slides presentation
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @return [Google::Apis::SlidesV1::Presentation] The presentation
    # @raise [StandardError] If the presentation cannot be retrieved
    def get_presentation(google_presentation_id)
      Rails.logger.info("Fetching presentation: #{google_presentation_id}")

      presentation = slides_service.get_presentation(google_presentation_id)

      Rails.logger.info("Successfully fetched presentation with #{presentation.slides&.length || 0} slides")

      presentation
    rescue StandardError => e
      Rails.logger.error("Failed to get presentation: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    # Execute a request on a presentation
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param requests [Hash] request object to execute
    # @param operation [String] Description of the operation being performed
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [StandardError] If the batch operation fails
    def execute_request(google_presentation_id, request, operation:)
      execute_batch_requests(google_presentation_id, [request], operation: operation)
    end

    # Execute a batch of requests on a presentation
    # @param google_presentation_id [String] The ID of the Google Slides presentation
    # @param requests [Array<Hash>] Array of request objects to execute
    # @param operation [String] Description of the operation being performed
    # @return [Google::Apis::SlidesV1::BatchUpdatePresentationResponse] The response from the API
    # @raise [StandardError] If the batch operation fails
    def execute_batch_requests(google_presentation_id, requests, operation:)
      Rails.logger.info("Executing #{operation} #{'request'.pluralize(requests.length)}: #{requests.inspect}")
      begin
        response = slides_service.batch_update_presentation(
          google_presentation_id,
          { requests: requests }
        )
        Rails.logger.info("Successfully completed #{operation}")
        response
      rescue StandardError => e
        Rails.logger.error("Failed to execute #{operation}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        raise
      end
    end
  end
end
