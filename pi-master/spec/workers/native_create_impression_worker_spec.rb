# frozen_string_literal: true
require 'spec_helper'

describe NativeCreateImpressionWorker do
  let!(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:user_agent) { 'Mozilla/5.0 Safari/000.00.001' }
  let(:url) { FFaker::Internet.http_url }
  let(:device) { create(:device, udid: udid) }
  let(:survey) { create(:survey) }
  let(:mobile_type) { 'ios' }

  before do
    Submission.delete_all
  end

  after do
    Submission.delete_all
  end

  it 'fills device_type' do
    device_type_param = { 'device_type' => 'native_mobile' }
    described_class.new.perform(impression_params.merge(device_type_param), device)
    expect(Submission.last.device_type).to eq 'native_mobile'
  end

  context 'when mobile_type is ios' do
    it 'creates an impression for ios' do
      expect { described_class.new.perform(impression_params, device) }.to change { Submission.count }.by(1)
      expect(Submission.last.ios?).to be true
    end
  end

  context 'when mobile_type is android' do
    let(:mobile_type) { 'android' }

    it 'creates an impression for android' do
      expect { described_class.new.perform(impression_params, device) }.to change { Submission.count }.by(1)
      expect(Submission.last.android?).to be true
    end
  end

  context 'when mobile_type is not present' do
    let(:mobile_type) { nil }

    it 'creates an impression without mobile_type' do
      expect { described_class.new.perform(impression_params, device) }.to change { Submission.count }.by(1)
      expect(Submission.last.ios?).to be false
      expect(Submission.last.android?).to be false
    end
  end

  it 'fires DeleteExcessiveImpressionsWorker asynchronously' do
    expect { described_class.new.perform(impression_params, device) }.to change { DeleteExcessiveImpressionsWorker.jobs.size }.by(1)
  end

  def impression_params
    { 'survey_id' => survey.id, 'submission_udid' => udid, 'device' => device, 'url' => url, 'user_agent' => user_agent, 'mobile_type' => mobile_type }
  end
end
