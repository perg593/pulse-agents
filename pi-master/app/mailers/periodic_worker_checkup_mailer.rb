# frozen_string_literal: true
class PeriodicWorkerCheckupMailer < ActionMailer::Base
  default cc: ["monitoring@pulseinsights.com"]

  def checkup_report(failed_workers)
    @failed_workers = failed_workers.map(&:to_s)

    mail(to: "ops@pulseinsights.com", bcc: "dev.pulseinsights@ekohe.com", subject: "Periodic report failures")
  end
end
