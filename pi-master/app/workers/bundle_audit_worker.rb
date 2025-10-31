# frozen_string_literal: true
require 'bundler/audit/cli'

class BundleAuditWorker
  include Sidekiq::Worker
  include Common

  DB_PATH = "/var/www/production/pi/shared/ruby-advisory-db"

  def perform
    tagged_logger.info "Beginning"

    update_vulnerability_db

    filename = "audit_output.json"
    check_for_vulnerabilities(filename)
  rescue SystemExit => e
    # This is expected, Bundler::Audit::CLI calls exit if it
    # finds any vulnerabilities
    results = parse_results(filename)

    if results.empty?
      tagged_logger.info "Found no vulnerabilities"
    else
      tagged_logger.info "Found #{results.count} vulnerabilities"
      DeveloperNotificationMailer.bundle_audit_vulnerabilities_detected(results).deliver
    end
  rescue StandardError => e
    tagged_logger.info "Error: #{e.inspect}"
    Rollbar.error(e, "BundleAuditWorker failed")
  ensure
    tagged_logger.info "Done"
  end

  def update_vulnerability_db
    unless Bundler::Audit::Database.exists?(DB_PATH)
      tagged_logger.info "No database found -- downloading"
      begin
        # This will run "git clone" twice, once in the specified path
        # and a second time in ~/.local/share.
        # The second will fail.
        Bundler::Audit::Database.download(path: DB_PATH)
      rescue SystemExit => e
        # failed because it tried writing to ~/.local/share
      end

      tagged_logger.info "Failed to download database!" unless Bundler::Audit::Database.exists?(DB_PATH)
    end

    begin
      tagged_logger.info "Updating database"
      db = Bundler::Audit::Database.new(DB_PATH)
      # This will run "git clone" twice, once in the specified path
      # and a second time in ~/.local/share.
      # The second will fail.
      db.update!
    rescue SystemExit => e
      # failed because it tried writing to ~/.local/share
    end
  end

  def check_for_vulnerabilities(filename)
    Bundler::Audit::CLI.start ["check", "--format", "json", "--output", filename, "--database", DB_PATH]
  end

  def parse_results(filename)
    output_file = File.new(filename)

    output = output_file.readline

    json_output = JSON.parse(output)

    json_output["results"].map do |result|
      BundleAudit::Result.new(result)
    end
  end
end
