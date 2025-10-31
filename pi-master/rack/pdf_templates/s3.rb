# frozen_string_literal: true

require 'aws-sdk'

require_relative "../credentials"

module Rack
  module PdfTemplates
    module S3
      # TODO: Logging
      def self.get_template_file_contents(object_key)
        credentials = ::Aws::Credentials.new(
          Rack::Credentials.credentials.aws[:access_key_id],
          Rack::Credentials.credentials.aws[:secret_access_key]
        )

        resource = Aws::S3::Resource.new(
          region: "us-west-2",
          credentials: credentials
        )

        object = resource.bucket('pi-pdf-templates').object(object_key)

        object.get.body.read
      end
    end
  end
end
