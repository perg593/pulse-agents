# frozen_string_literal: true
require 'spec_helper'

include ReportHelper

PERIODIC_WORKERS = [
  AstraZenecaWorker,
  AstraZenecaAggregateWorker,
  PeriodicReportWorkers::BenMooreWorker, NewJerseyTransitWorker,
  # NBAEmailSurveyWorker
  Azurity::AzurityWorker,
  # MeleeWorker,
  SummerDiscovery::SummerDiscoveryWorker,
  Crocs::CrocsWorker
].freeze

MORE_THAN_ONCE_DAILY_WORKERS = [
  MeleeWorker
].freeze

describe PeriodicReportWorkers::CheckupWorker do
  before do
    ActionMailer::Base.deliveries.clear
  end

  it "sends an e-mail if an observed worker failed to complete on schedule" do
    PERIODIC_WORKERS.each_with_index do |worker, i|
      mark_all_as_delivered
      allow(worker).to receive(:delivered_as_expected?).and_return(false)

      described_class.new.perform
      expect(num_checkup_emails).to eq(i + 1)
    end
  end

  context "when an observed worker that runs more than once a day completes all of its runs on schedule" do
    before do
      mark_all_as_delivered

      MORE_THAN_ONCE_DAILY_WORKERS.each do |worker|
        allow(worker).to receive_messages(delivered_as_expected?: false, delivered_all_for_date?: true)
      end
    end

    it "sends no e-mail if all observed workers completed on schedule" do
      described_class.new.perform
      expect(num_checkup_emails).to eq(0)
    end
  end

  it "sends no e-mail if all observed workers completed on schedule" do
    mark_all_as_delivered

    described_class.new.perform
    expect(num_checkup_emails).to eq(0)
  end

  def num_checkup_emails
    ActionMailer::Base.deliveries.count { |delivery| delivery.subject == "Periodic report failures" }
  end

  def mark_all_as_delivered
    PERIODIC_WORKERS.each do |worker|
      allow(worker).to receive(:delivered_as_expected?).and_return(true)
    end
  end
end
