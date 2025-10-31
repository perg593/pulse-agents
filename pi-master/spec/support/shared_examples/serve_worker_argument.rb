# frozen_string_literal: true

RSpec.shared_examples "serve worker argument" do
  let(:account) { survey.account }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }
  let(:base_url) do
    "/serve?identifier=#{account.identifier}&" \
      "callback=#{callback}&udid=#{udid}&" \
      "device_type=#{device_type}&client_key=#{client_key}"
  end
  let(:extra_parameters) { '' }
  let(:extra_headers) { {} }
  let(:referer_url) { 'http://localhost:3000' }
  let(:device_udid) { udid }

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:ip_address) { "192.168.0.1" }

  def expected_worker_keys
    %w(
      client_key
      custom_data
      device_id
      device_type
      ip_address
      pageview_count
      submission_udid
      survey_id
      udid
      url
      user_agent
      visit_count
    )
  end

  before do
    @device = create(:device, udid: device_udid)

    headers = {
      "Referer" => referer_url,
      "X_REAL_IP" => ip_address
    }.merge(extra_headers)

    rack_app_as_json("#{base_url}#{extra_parameters}", headers)

    queue = Sidekiq::Queue.new
    @job_arguments = queue.first["args"][0]
  end

  it "queues ServeWorker" do
    queue = Sidekiq::Queue.new
    job_class = queue.first["class"]

    expect(job_class).to eq("ServeWorker")
  end

  it "queues ServeWorker with the expected arguments" do
    expect(@job_arguments.keys).to match_array(expected_worker_keys)
  end

  describe "device_id" do
    subject { @job_arguments["device_id"] }

    context "when device associated with provided udid exists" do
      let(:device_udid) { udid }

      it { is_expected.to eq @device.id.to_s }
    end

    context "when device associated with provided udid does not exist" do
      let(:device_udid) { udid2 }

      it { is_expected.to be_nil }
    end
  end

  describe "device_type" do
    subject { @job_arguments["device_type"] }

    it { is_expected.to eq device_type }
  end

  describe "ip_address" do
    subject { @job_arguments["ip_address"] }

    it { is_expected.to eq ip_address }
  end

  describe "pageview_count" do
    subject { @job_arguments["pageview_count"] }

    context "when pageview_count is provided" do
      let(:extra_parameters) { "&pageview_count=42" }

      it { is_expected.to eq 42 }
    end

    context "when pageview_count is not provided" do
      it { is_expected.to eq 0 }
    end
  end

  describe "submission_udid" do
    subject { @job_arguments["submission_udid"] }

    # Randomly generated on the backend
    # We could mock the backend's udid generator, but that's gross
    it { is_expected.not_to be_nil }
  end

  describe "udid" do
    subject { @job_arguments["udid"] }

    it { is_expected.to eq udid }
  end

  describe "user_agent" do
    subject { @job_arguments["user_agent"] }

    it { is_expected.to eq "Ruby" }
  end

  describe "visit_count" do
    subject { @job_arguments["visit_count"] }

    context "when visit_count is provided" do
      let(:extra_parameters) { "&visit_count=42" }

      it { is_expected.to eq 42 }
    end

    context "when visit_count is not provided" do
      it { is_expected.to eq 0 }
    end
  end

  describe "custom_data" do
    subject { @job_arguments["custom_data"] }

    context "when custom_data has been provided" do
      let(:custom_data) { { a: '3', b: 'foobar' } }
      let(:extra_parameters) { "&custom_data=#{custom_data.to_json}" }

      it { is_expected.to eq custom_data.to_json }
    end
  end

  describe "client_key" do
    subject { @job_arguments["client_key"] }

    context "when client_key has been provided" do
      it { is_expected.to eq client_key }
    end
  end
end
