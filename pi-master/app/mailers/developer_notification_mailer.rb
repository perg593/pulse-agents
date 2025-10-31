# frozen_string_literal: true

class DeveloperNotificationMailer < ActionMailer::Base
  default to: "dev.pulseinsights@ekohe.com"

  layout "mailers/developers"

  # results is a BundleAudit::Result object
  def bundle_audit_vulnerabilities_detected(results)
    @results = results

    mail(subject: "Bundle-audit detected security vulnerabilities")
  end

  def yarn_audit_vulnerabilities_detected(results)
    @results = results

    mail(subject: "yarn audit detected security vulnerabilities")
  end
end
