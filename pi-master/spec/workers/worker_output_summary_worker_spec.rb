# frozen_string_literal: true
require 'spec_helper'

describe WorkerOutputSummaryWorker do
  before do
    ActionMailer::Base.deliveries.clear
  end

  it 'sends email to correct recipients' do
    described_class.new.perform
    email = ActionMailer::Base.deliveries.last
    recipients = email.to
    cc_recipients = email.cc
    expect(recipients.count).to eq 1
    expect(recipients.first).to eq 'monitoring@pulseinsights.com'
    expect(cc_recipients).to contain_exactly("dev.pulseinsights@ekohe.com", "ops@pulseinsights.com")
  end

  context 'when a time period is specified' do
    it 'contains worker outputs made in the specified time period' do
      5.times { |n| create_worker_output_copy(n.hours.ago) }

      described_class.new.perform(start_time: (3.hours + 30.minutes).ago, end_time: Time.current)

      email_body = ActionMailer::Base.deliveries.last.body
      WorkerOutputCopy.order(:updated_at).each do |worker_output_copy|
        if worker_output_copy.updated_at >= (3.hours + 30.minutes).ago
          expect(email_body).to include worker_output_copy.signed_url
        else
          expect(email_body).not_to include worker_output_copy.signed_url
        end
      end
    end
  end

  context 'when no time period is specified' do
    it 'contains worker output from yesterday' do
      worker_output_copies = [1.day.ago, Time.current].map { |timestamp| create_worker_output_copy(timestamp) }

      described_class.new.perform

      email_body = ActionMailer::Base.deliveries.last.body
      expect(email_body).to include worker_output_copies.first.signed_url
      expect(email_body).not_to include worker_output_copies.last.signed_url
    end
  end

  it 'lists output in the order of worker name and time' do
    ('a'..'c').each do |char|
      3.times do |n|
        worker_name = "#{char}_worker"
        updated_at = 1.day.ago.end_of_day - n.hours
        WorkerOutputCopy.create(worker_name: worker_name, file_name: "#{worker_name}_#{n}.csv", signed_url: "https://#{worker_name}", updated_at: updated_at)
      end
    end

    described_class.new.perform

    parsed_email = Nokogiri::HTML.parse(ActionMailer::Base.deliveries.last.body.to_s)
    filename_row = 2
    filenames = parsed_email.xpath("//tr/td[#{filename_row}]").map(&:text)
    expect(filenames).to eq WorkerOutputCopy.order(:worker_name, :updated_at).pluck(:file_name)
  end

  def create_worker_output_copy(updated_at)
    worker_name = "#{FFaker::Lorem.word.underscore}_worker"
    file_name = "#{worker_name}.#{%w(csv json xlsx).sample}"
    signed_url = "https://s3-bucket/#{SecureRandom.hex}#{file_name}"
    WorkerOutputCopy.create(worker_name: worker_name, file_name: file_name, signed_url: signed_url, updated_at: updated_at)
  end
end
