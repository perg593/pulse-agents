# frozen_string_literal: true

require File.join(File.dirname(__FILE__), '../../lib/logging')
require File.join(File.dirname(__FILE__), 'sql_helpers')

# rubocop:disable Metrics/ModuleLength
module Common
  class PostgresExecutionError < StandardError; end

  include Logging
  include SQLHelpers

  # TODO: separate this file("common.rb") into "fired by Rails" and "fired by Rack"
  include Rack::PiLogger
  include Rack::Influx

  def environment
    @environment ||= ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
  end

  # The connection is establish by postgres_execute the first time a SQL request is initiated
  def postgres_connect!(options = {})
    config = postgres_configuration(options)
    if options[:readonly]
      @ro_pg_connection = PG.connect(config)
    else
      @pg_connection = PG.connect(config)
    end
  rescue StandardError => e
    log "Error connecting to database!"
    log e.inspect
    log config.inspect
  end

  def postgres_disconnect!
    @pg_connection&.finish
    @pg_connection = nil
    @ro_pg_connection&.finish
    @ro_pg_connection = nil
  end

  # Postgres configuration is read from Rails database.yml
  #
  # Options:
  #   config_yml: Custom config yml. Used for testing
  #   readonly  : Can be specified if the worker is running on the reporting box
  #
  def postgres_configuration(options = {})
    database_yml = options[:config_yml] || YAML.load_file(File.expand_path('../../config/database.yml', __dir__), aliases: true)
    rails_config = database_yml[environment]

    postgres_config ={
      dbname:   rails_config["database"],
      user:     rails_config["username"],
      password: rails_config["password"],
      host:     rails_config["host"],
      port:     rails_config["port"]
    }

    return postgres_config if rails_config["makara"].nil?

    role = options[:readonly] ? 'slave' : 'master'

    proxied_connections = rails_config["makara"]["connections"]
    selected_connection = proxied_connections.select { |c| c["role"] == role }[0]

    postgres_config.merge(host: selected_connection['host'], port: selected_connection['port'])
  end

  # Main method that execute sql requests
  def postgres_execute(sql, readonly: false, retry_count: 0)
    connection = readonly ? @ro_pg_connection : @pg_connection
    postgres_connect!(readonly: readonly) if connection.nil?
    connection = readonly ? @ro_pg_connection : @pg_connection

    connection.exec(sql)
  rescue StandardError => e
    if e.is_a?(PG::UnableToSend) && retry_count.zero?
      log 'Trying to reconnect to PostgreSQL...'
      postgres_connect!(readonly: readonly)
      return postgres_execute(sql, readonly: readonly, retry_count: retry_count + 1)
    end

    Rollbar.error(e, "SQL Error: #{e.inspect}", sql: sql)

    # raise so Sidekiq retries. Configured to be ignored by Rollbar, as the reporting is done in better format with the above code
    raise PostgresExecutionError
  end

  def obfuscate_ip_address(ip_address, survey_id)
    return '' if ip_address.blank?
    return ip_address if survey_id.blank?

    account_row = Account.joins(:surveys).where(surveys: { id: survey_id }).select(:ip_storage_policy).limit(1)

    if account_row.exists?
      ip_storage_policy = account_row.first.ip_storage_policy
    else
      report_to_rollbar('ServeWorker: No Account', survey_id: survey_id, sql: account_row.to_sql)
    end

    case ip_storage_policy
    when "store_full"
      ip_address
    when "store_obfuscated"
      ip_address.gsub(/\.\d*$/, "")
    when "store_none"
      ''
    end
  end

  def report_to_rollbar(message, options = {})
    log("#{message} - #{options}")
    Rollbar.error(message, options)
  end

  def parse_custom_data(custom_data)
    JSON.parse(custom_data)
  rescue
    {}
  end

  def parse_url_params(url)
    Rack::Utils.parse_query(URI(url || '').query)
  end

  # When S3 returns an error response, the Ruby SDK constructs and raises an error
  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Errors.html
  #
  # credentials - overrides the simple [:access_key_id, :secret_access_key] credentials with customized S3 credentials, e.g. Aws::AssumeRoleCredentials
  def transfer_to_s3(filename, s3_config, credentials: nil)
    return if Rails.env.test?

    s3_credentials = credentials || Aws::Credentials.new(s3_config[:access_key_id], s3_config[:secret_access_key])

    s3 = Aws::S3::Resource.new(region: s3_config[:region], credentials: s3_credentials)

    obj = s3.bucket(s3_config[:bucket_name]).object("#{s3_config[:bucket_path]}#{filename}")
    obj.upload_file("tmp/#{filename}", server_side_encryption: 'AES256', content_type: file_content_type(filename))

    tagged_logger.info "#{filename} was transmitted to S3"

    upload_copy_to_s3(filename)

    obj.presigned_url(:get, expires_in: 7 * 86400) # expires in 7 days. https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html
  end

  def upload_copy_to_s3(filename)
    return unless %w(production staging develop).include? Rails.env

    tagged_logger.info 'Uploading copy to S3'
    s3 = Aws::S3::Resource.new(region: 'us-west-2')
    obj = s3.bucket(worker_output_s3_bucket_name).object(filename)
    tagged_logger.error 'Failed to upload' and return unless obj.upload_file("tmp/#{filename}", content_type: file_content_type(filename))

    signed_url = obj.presigned_url(:get, expires_in: 7 * 86400) # expires in 7 days. https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html
    tagged_logger.info "Uploaded copy of #{filename} to #{signed_url}"

    WorkerOutputCopy.create(worker_name: self.class.name.underscore, file_name: filename, signed_url: signed_url)
  end

  def worker_output_s3_bucket_name
    "pi-worker-output-copies-#{Rails.env}"
  end

  def file_content_type(filename)
    case File.extname(filename)
    when /csv/
      'text/csv'
    when /json/
      'application/json'
    else
      'text/plain'
    end
  end

  def log_worker_activity_to_influxdb(success:, input:)
    tagged_logger.info 'Logging to InfluxDB'
    influxdb_connect!

    write_to_influxdb({ series: 'pi_reactive_worker_activity', tags: { worker_name: self.class.name }, values: { success: success, input: input.to_json } })
    tagged_logger.info "Successfully logged these to InfluxDB - success: #{success}, input: #{input}"
  rescue StandardError => e
    tagged_logger.error "Failed to log to InfluxDB - #{e}"
  end
end
