# frozen_string_literal: true
module PeriodicReportWorkers
  class CheckupWorker
    include Sidekiq::Worker
    include Rack::PiLogger

    PERIODIC_WORKERS = [
      AstraZenecaWorker,
      AstraZenecaAggregateWorker,
      PeriodicReportWorkers::BenMooreWorker, NewJerseyTransitWorker,
      # NBAEmailSurveyWorker
      Azurity::AzurityWorker, SummerDiscovery::SummerDiscoveryWorker,
      Crocs::CrocsWorker
    ].freeze

    MORE_THAN_ONCE_DAILY_WORKERS = [
      # MeleeWorker,
    ].freeze

    def perform
      failed_workers = PERIODIC_WORKERS.reject(&:delivered_as_expected?)

      # This job runs once a day, but some reports are run more than once a day, so we
      # need to check for all reports for the previous day, not just the last report.
      failed_workers += MORE_THAN_ONCE_DAILY_WORKERS.reject { |worker| worker.delivered_all_for_date?(1.day.ago) }

      return unless failed_workers.present?

      PeriodicWorkerCheckupMailer.checkup_report(failed_workers).deliver_now
    end
  end
end
