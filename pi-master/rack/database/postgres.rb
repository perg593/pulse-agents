# frozen_string_literal: true
module Rack
  module Postgres
    include PiLogger

    require 'pg'
    require 'yaml'

    CONNECTION_ERRORS = {
      NoMethodError => 'No PostgreSQL connection, connecting...',
      PG::UnableToSend => 'PostgreSQL connection failed, reconnecting...',
      PG::ConnectionBad => 'PostgreSQL not responsive, connecting...'
    }.freeze

    # TODO: Implement a centralized, universally accessible source of truth method that operates independently of instance variables
    def environment
      @environment || ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
    end

    # The connection is establish by postgres_execute the first time a SQL request is initiated
    def postgres_connect!
      config = postgres_configuration
      @pg_connection = PG.connect(config)
      log "Connected to PostgreSQL!"
    rescue StandardError => e
      log "Error connecting to database!"
      log e.inspect
      log config.inspect
    end

    # Postgres configuration is read from Rails database.yml
    def postgres_configuration
      database_yml = YAML.load_file(::File.expand_path('../../config/database.yml', __dir__), aliases: true)
      config = database_yml[environment]

      raise "Not supporting #{config["adapter"]}, but only PostgreSQL" unless config["adapter"].match?(/postgresql/)

      { dbname: config["database"], user: config["username"], password: config["password"], host: config["rack-host"], port: config["port"] }
    end

    # Main method that execute sql requests
    def postgres_execute(sql)
      @pg_connection.exec(sql)
    rescue StandardError => e
      if connection_error?(e)
        log_connection_error(e)
        postgres_connect!

        begin
          return @pg_connection.exec(sql)
        rescue StandardError => e
          # Fall through to error reporting below
        end
      end

      report_to_rollbar("SQL Error: #{e.inspect}", sql: sql, full_message: e.full_message)
      false
    end

    # Helper method that creates an array for all the rows
    def postgres_all(sql)
      output = []
      postgres_execute(sql).each_row do |row|
        output << row
      end
      output
    end

    # As a heartbeat test, get the columns of the surveys table and check if there are more than one column
    def postgres_heartbeat
      columns = postgres_all("SELECT column_name FROM information_schema.columns where table_name = 'surveys';")
      raise "error" unless columns.size > 1
    end

    private

    def connection_error?(error)
      CONNECTION_ERRORS.key?(error.class)
    end

    def log_connection_error(error)
      log(CONNECTION_ERRORS[error.class])
    end
  end
end
