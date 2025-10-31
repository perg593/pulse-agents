# frozen_string_literal: true

require 'influxdb'

class InfluxDBClient
  attr_accessor :influxdb

  def initialize
    environment = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
    database_yml = YAML.load_file(::File.join(::File.dirname(__FILE__), '..', 'config', 'database.yml'), aliases: true)[environment]
    settings = database_yml['influxdb']

    if settings.nil?
      raise "Please configure InfluxDB connection settings in database.yml"
    end
    database_name = database_yml['influxdb'].delete('database')
    @influxdb = InfluxDB::Client.new(database_name,
                                     username: settings["username"],
                                     password: settings["password"],
                                     hosts: settings["hosts"],
                                     port: settings["port"],
                                     use_ssl: settings["use_ssl"],
                                     retry: settings["retry"])
  end
end
