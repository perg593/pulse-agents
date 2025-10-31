# frozen_string_literal: true
require 'aws-sdk'

aws_credentials = Rails.application.credentials.aws

Aws.config.update(region: 'us-west-2',
                  credentials: Aws::Credentials.new(aws_credentials[:access_key_id], aws_credentials[:secret_access_key]))

task :cloudfront_invalidate_files, [:env] do |_t, args|
  env = args.env

  client = Aws::CloudFront::Client.new
  client.create_invalidation(
    distribution_id: distribution_id(env),
    invalidation_batch: {
      paths: { quantity: 1, items: ["/*"] },
      caller_reference: "[#{Time.current.to_i}] JS invalidation"
    }
  )
end

def distribution_id(env)
  { production: 'E2VEP07NTVCEP8', staging: 'E38XWXL7MR0QK8', develop: 'E28C3OG8RO4WSI' }[env.to_sym]
end
