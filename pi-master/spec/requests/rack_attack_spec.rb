# frozen_string_literal: true
require 'spec_helper'

RSpec.describe "Rack::Attack" do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:headers) { {"REMOTE_ADDR" => "1.2.3.4"} }
  let(:user) { create(:user) }

  before do
    # Rack::Attack stores the state in Rails.cache by default
    # And Rails.cache is configured to ActiveSupport::Cache::NullStore in test.rb, which clears stored values at the end of a request
    # so that we mock Rails.cache with an ActiveSupport::Cache::MemoryStore instance to keep the Rack::Attack states across requests
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    Rack::Attack.enabled = true
    Rack::Attack.reset!
  end

  after do
    Rack::Attack.reset!
    Rack::Attack.enabled = false
  end

  describe "block ip addresses requesting any path too frequently" do
    before do
      create_assets
      sign_in
    end

    after do
      delete_assets
    end

    describe "maxretry" do
      let(:invalid_path) { "/invalid_path" }

      it "blocks an ip after 100 requests excluding '/assets' and '/packs'" do
        100.times { expect_request_not_forbidden random_path }
        expect_request_forbidden random_path
      end

      it "blocks an ip after 100 invalid requests" do
        100.times { expect_request_not_forbidden invalid_path }
        expect_request_forbidden invalid_path
      end

      it "does not block an ip after 100 requests matching '/assets'" do
        100.times { expect_request_not_forbidden "/assets/sample.txt" }
        expect_request_not_forbidden root_path
      end

      it "does not block an ip after 100 requests matching 'packs'" do
        100.times { expect_request_not_forbidden "/packs/sample.txt" }
        expect_request_not_forbidden root_path
      end
    end

    describe "findtime" do
      let(:beginning_of_hour) { Time.current.beginning_of_hour }

      it "allows 99 requests per 3 minutes" do
        travel_to(beginning_of_hour) do
          99.times { expect_request_not_forbidden(random_path) }
        end

        travel_to(beginning_of_hour + 3.minutes) do
          99.times { expect_request_not_forbidden(random_path) }
        end

        travel_to(beginning_of_hour + 6.minutes) do
          99.times { expect_request_not_forbidden(random_path) }
        end
      end

      it "blocks an ip after 100 requests within 3 minutes" do
        travel_to(beginning_of_hour) do
          99.times { expect_request_not_forbidden(random_path) }
        end

        travel_to(beginning_of_hour + 2.minutes) do
          expect_request_not_forbidden random_path
          expect_request_forbidden random_path
        end
      end
    end

    describe "bantime" do
      it "allows requests after blocking ip for 1 hour" do
        100.times { expect_request_not_forbidden random_path }

        expect_request_forbidden random_path

        travel_to 61.minutes.from_now do
          expect_request_not_forbidden random_path
        end
      end
    end
  end

  describe "GET /report_jobs/:id/status" do
    let(:account) { user.account }
    let(:survey) { create(:survey, account: account) }
    let(:report_job) { create(:report_job, user: user, survey: survey, current_user_email: user.email) }

    it "throttles ip for 20 requests per minute" do
      20.times { expect_not_too_many_requests status_report_job_path(report_job) }
      expect_too_many_requests status_report_job_path(report_job)

      travel_to 1.minute.from_now do
        20.times { expect_not_too_many_requests status_report_job_path(report_job) }
      end
    end

    it "does not block ip after 100 requests within 3 minutes" do
      100.times { get status_report_job_path(report_job), headers: headers }
      expect_request_not_forbidden status_report_job_path(report_job)
    end
  end

  def create_assets
    %w(assets packs).each do |resource_folder|
      directory_path = "#{Rails.root}/public/#{resource_folder}"
      FileUtils.mkdir_p(directory_path)
      File.write("#{directory_path}/sample.txt", "hello world!")
    end
  end

  def delete_assets
    %w(assets packs).each do |resource_folder|
      File.delete("#{Rails.root}/public/#{resource_folder}/sample.txt")
    end
  end

  def sign_in
    post sign_in_path, params: { user: { email: user.email, password: user.password } }
  end

  def random_path
    %w(/surveys /scheduled_reports /automations /password/reset).sample
  end

  def expect_request_not_forbidden(request_path)
    get request_path, headers: headers
    expect(response.body).not_to include 'Forbidden'
    expect(response).not_to have_http_status(:forbidden)
  end

  def expect_request_forbidden(request_path)
    get request_path, headers: headers

    # Debugging for #1365
    puts Rails.cache.instance_variable_get(:@data).keys.map { |key| {key: key, value: Rails.cache.fetch(key)} }

    expect(response.body).to include 'Forbidden'
    expect(response).to have_http_status(:forbidden)
  end

  def expect_not_too_many_requests(request_path)
    get request_path, headers: headers
    expect(response.body).not_to include 'Retry later'
    expect(response).not_to have_http_status(:too_many_requests)
  end

  def expect_too_many_requests(request_path)
    get request_path, headers: headers
    expect(response.body).to include 'Retry later'
    expect(response).to have_http_status(:too_many_requests)
  end
end
