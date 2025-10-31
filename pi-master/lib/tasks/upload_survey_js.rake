# frozen_string_literal: true
require 'aws-sdk'

aws_credentials = Rails.application.credentials.aws

Aws.config.update(region: 'us-west-2',
                  credentials: Aws::Credentials.new(aws_credentials[:access_key_id], aws_credentials[:secret_access_key]))

task :upload_survey_js, [:env] do |_t, args|
  env = args.env
  s3_bucket = get_s3_bucket(env)
  abort 'This task can be launched only in develop, staging or production environments' unless s3_bucket

  s3 = Aws::S3::Resource.new(region: 'us-west-2')

  upload_js_to_s3(s3.bucket(s3_bucket), 'surveys.js')
  upload_js_to_s3(s3.bucket(s3_bucket), 'surveys_ncb.js')
end

def upload_js_to_s3(bucket, file_name)
  file_path = Dir.glob("public/assets/#{file_name}").first
  abort "#{file_name} not found. JS files found in public/assets: #{Dir.glob('public/assets/*.js')}" if file_path.nil?

  obj = bucket.object(file_name)
  prepend_date_as_comment(file_path)
  obj.upload_file file_path, acl: 'public-read', cache_control: "max-age=86400", content_type: "application/javascript"
end

def prepend_date_as_comment(file_path)
  f = File.open(file_path, "r+")
  lines = f.readlines
  f.close
  lines = ["// Precompiled on #{Time.current}\n"] + lines
  output = File.new(file_path, "w")
  lines.each { |line| output.write line }
  output.close
end

def get_s3_bucket(env)
  { production: 'pi-js-survey', staging: 'pi-staging-js-survey', develop: 'pi-develop-js-survey'}[env.to_sym]
end
