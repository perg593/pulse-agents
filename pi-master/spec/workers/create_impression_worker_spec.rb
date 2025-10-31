# frozen_string_literal: true
require 'spec_helper'

describe CreateImpressionWorker do
  before do
    Sidekiq::Worker.clear_all
    Submission.delete_all
  end

  after do
    Submission.delete_all
  end

  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:device) { create(:device, udid: udid) }

  let(:ip_address) { FFaker::Internet.ip_v4_address }
  let(:user_agent) { 'Mozilla/5.0 (X11; Linux x86_64)' }
  let(:url) { FFaker::Internet.http_url }

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'creates an impression' do
    expect { described_class.new.perform(impression_params) }.to change { Submission.count }.from(0).to(1)
  end

  it 'sets 1 as a default value to visit_count and pageview_count' do
    described_class.new.perform(impression_params.except('visit_count', 'pageview_count'))
    submission = Submission.first
    expect(submission.visit_count).to eq 1
    expect(submission.pageview_count).to eq 1
  end

  it 'stores ip addresses according to account settings' do
    Account.ip_storage_policies.each do |storage_policy_name, storage_policy_value|
      account.update(ip_storage_policy: storage_policy_value)

      expect { described_class.new.perform(impression_params) }.to change { Submission.count }.by(1)

      case storage_policy_name
      when "store_full"
        expect(Submission.last.ip_address).to eq(ip_address)
      when "store_obfuscated"
        # everything but the last octet
        expect(Submission.last.ip_address).to eq(ip_address.gsub(/\.\d*$/, ""))
      when "store_none"
        expect(Submission.last.ip_address).to eq('')
      else
        raise "unrecognized storage policy name: #{storage_policy_name}"
      end
    end
  end

  it 'fires DeleteExcessiveImpressionsWorker asynchronously' do
    expect { described_class.new.perform(impression_params) }.to change { DeleteExcessiveImpressionsWorker.jobs.size }.by(1)
  end

  def impression_params
    { 'survey_id' => survey.id, 'udid' => udid, 'device' => device, 'url' => url, 'ip_address' => ip_address,
      'user_agent' => user_agent, 'visit_count' => 3, 'pageview_count' => 3 }
  end

  describe "URL decoding" do
    context "when a non-Waterworks encoded URL is received" do
      let(:url) { "https://www.pulseinsights.com/us_en/?pi_present=5790&contactid=%7B%7B1087601%7D%7D&incidentid=%7B%7B300341%7D%7D" }

      before do
        described_class.new.perform(impression_params)
        @submission = Submission.first
      end

      it "saves the raw URL" do
        expect(@submission.url).to eq(url)
      end
    end

    context "when a Waterworks encoded URL is received" do
      let(:url) { "https://www.waterworks.com/us_en/?pi_present=5790&contactid=%7B%7B1087601%7D%7D&incidentid=%7B%7B300341%7D%7D" }

      before do
        described_class.new.perform(impression_params)
        @submission = Submission.first
      end

      it "decodes the URL before saving it" do
        expect(@submission.url).to eq(CGI.unescape(url))
      end
    end
  end
end
