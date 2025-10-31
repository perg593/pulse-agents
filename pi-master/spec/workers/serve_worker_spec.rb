# frozen_string_literal: true
require 'spec_helper'

describe ServeWorker do
  before do
    Sidekiq::Worker.clear_all
    Device.delete_all
    Submission.delete_all

    @account         = create(:account)
    @survey          = create(:survey)
    @survey.account  = @account
    @survey.save
  end

  after do
    Device.delete_all
    Submission.delete_all
  end

  before :all do
    @submission_udid = SecureRandom.uuid
    @device          = nil
    @udid            = '00000000-0000-4000-f000-000000000001'
    @custom_data     = {}
    @ip_address      = ''
    @user_agent      = ''
    @url             = ''
    @visit_count     = 0
    @pageview_count  = 0
    @device_type     = ''
    @client_key      = 'my_awesome_client_key'
  end

  it 'is retryable' do
    expect(described_class).to be_retryable true
  end

  it 'creates a new device if not provided' do
    expect(Device.count).to eq(0)

    described_class.new.perform(serve_worker_params(@device))

    expect(Device.count).to eq(1)
  end

  it 'does not create a new device if provided' do
    expect(Device.count).to eq(0)

    device = CreateDeviceWorker.new.perform(@udid)

    expect(Device.count).to eq(1)

    described_class.new.perform(serve_worker_params(device[:id]))

    expect(Device.count).to eq(1)
  end

  describe 'client key' do
    it 'is saved if provided' do
      expect(Device.count).to eq(0)
      expect(Submission.count).to eq(0)

      described_class.new.perform(serve_worker_params(@device))

      expect(Device.count).to eq(1)
      expect(Submission.count).to eq(1)
      expect(Device.last.client_key).to eq(@client_key)
      expect(Submission.last.client_key).to eq(@client_key)
    end

    it 'stays null if not provided' do
      expect(Device.count).to eq(0)
      expect(Submission.count).to eq(0)

      params = serve_worker_params(@device)
      params['client_key'] = nil

      described_class.new.perform(params)

      expect(Device.count).to eq(1)
      expect(Submission.count).to eq(1)
      expect(Device.last.client_key).to be_nil
      expect(Submission.last.client_key).to be_nil
    end

    it 'is overwrite if already existing' do
      existing_client_key = 'my_existing_client_key'

      device = CreateDeviceWorker.new.perform(@udid)
      expect(Device.count).to eq(1)

      device.update(client_key: existing_client_key)
      expect(device[:client_key]).to eq(existing_client_key)

      described_class.new.perform(serve_worker_params(device[:id]))

      expect(Device.count).to eq(1)
      expect(Device.last.client_key).to eq(@client_key)
    end
  end

  def serve_worker_params(device_id)
    {
      'identifier' => @account.identifier,
      'survey_id' => @survey.id,
      'submission_udid' => @submission_udid,
      'device_id' => device_id,
      'udid' => @udid,
      'url' => @url,
      'ip_address' => @ip_address,
      'user_agent' => @user_agent,
      'custom_data' => @custom_data,
      'device_type' => @device_type,
      'visit_count' => @visit_count,
      'pageview_count' => @pageview_count,
      'client_key' => @client_key
    }
  end
end
