# frozen_string_literal: true

# Shared examples for a rack endpoint that returns surveys according to client key triggers
RSpec.shared_examples "rack client key targeting" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }
  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:device) { create(:device, udid: udid) }

  def make_call(account, client_key_param)
    raise NotImplementedError, "You must implement 'make_call' to use 'rack client key targeting'"
  end

  def assert_returned_survey(json_response)
    expect(json_response.dig("survey", "id").to_i).not_to eq(0)
  end

  def assert_did_not_return_survey(json_response)
    expect(json_response).to eq({})
  end

  describe "client key trigger" do
    before do
      @trigger = create(:client_key_trigger, survey_id: survey.id)
    end

    context "when client_key_presence is enabled" do
      before do
        @trigger.update(client_key_presence: true)
      end

      it "returns the survey if device with client_key exists" do
        device.update(client_key: "toto")

        json_response = make_call(account, { client_key: "toto" })

        assert_returned_survey(json_response)
      end

      it "does not return the survey if no client key was passed" do
        json_response = make_call(account, {})

        assert_did_not_return_survey(json_response)
      end

      it "does not return the survey if no device with client_key exists" do
        device.update(client_key: "tutu")

        json_response = make_call(account, { client_key: "toto" })

        assert_did_not_return_survey(json_response)
      end
    end

    context "when client_key_presence is disabled" do
      before do
        @trigger.update(client_key_presence: false)
      end

      it "returns the survey" do
        json_response = make_call(account, {})

        assert_returned_survey(json_response)
      end
    end
  end
end
