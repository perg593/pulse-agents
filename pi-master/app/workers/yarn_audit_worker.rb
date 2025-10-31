# frozen_string_literal: true
require 'bundler/audit/cli'

class YarnAuditWorker
  include Sidekiq::Worker
  include Common

  def perform
    tagged_logger.info "Beginning"

    results = check_for_vulnerabilities

    if results.empty?
      tagged_logger.info "Found no vulnerabilities"
    else
      tagged_logger.info "Found vulnerabilities"
      DeveloperNotificationMailer.yarn_audit_vulnerabilities_detected(results).deliver
    end
  rescue StandardError => e
    tagged_logger.info "Error: #{e.inspect}"
    Rollbar.error(e, "YarnAuditWorker failed")
  ensure
    tagged_logger.info "Done"
  end

  def check_for_vulnerabilities
    results = `(cd #{Rails.root}; yarn npm audit --all --json)`
    results = JSON.parse(results)
    vulnerability_counts = results["metadata"]["vulnerabilities"]

    vulnerability_counts.values.any?(&:positive?) ? results : []
  end
end
