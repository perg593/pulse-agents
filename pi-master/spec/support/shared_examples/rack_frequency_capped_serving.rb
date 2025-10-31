# frozen_string_literal: true

# Shared examples for a rack endpoint that returns surveys according to user-level frequency capping limits
RSpec.shared_examples "rack frequency capped serving" do
  let!(:survey) { create(:survey, account: account) }

  let(:account) { create(:account) }
  let(:device) { create(:device, udid: udid) }

  def make_call(account, preview_mode: false)
    raise NotImplementedError, "You must implement 'make_call' to use 'rack frequency capped serving'"
  end

  def it_should_return_survey(preview_mode: false)
    json_response = make_call(account, preview_mode: preview_mode)

    expect(json_response["survey"]["id"]).not_to eq(0)
  end

  def it_should_not_return_survey
    json_response = make_call(account)

    assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
  end

  describe "user-level frequency capping" do
    context "when disabled" do
      let(:account) { create(:account, frequency_cap_enabled: false) }

      it "serves the survey" do
        it_should_return_survey
      end
    end

    context "when not capped" do
      let(:account) { create(:account, frequency_cap_enabled: true, frequency_cap_type: 'hours', frequency_cap_limit: 1, frequency_cap_duration: 5) }

      before do
        create(:submission, device_id: device.id, survey_id: survey.id, created_at: 6.hours.ago)
      end

      it "serves the survey" do
        it_should_return_survey
      end
    end

    context "when capped" do
      let(:account) { create(:account, frequency_cap_enabled: true, frequency_cap_type: 'hours', frequency_cap_limit: 1, frequency_cap_duration: 2) }

      context 'with served impressions' do
        before do
          create(:submission, device_id: device.id, survey_id: survey.id, created_at: 30.minutes.ago)
        end

        it "serves the survey" do
          it_should_return_survey
        end
      end

      context 'with viewed impressions' do
        before do
          create(:submission, device_id: device.id, survey_id: survey.id, created_at: 30.minutes.ago, viewed_at: 30.minutes.ago)
        end

        it "does not serve the survey" do
          it_should_not_return_survey
        end

        context "when preview mode is enabled" do
          it "serves the survey" do
            it_should_return_survey(preview_mode: true)
          end
        end
      end
    end

    context "when capped minutes" do
      let(:account) { create(:account, frequency_cap_enabled: true, frequency_cap_type: 'minutes', frequency_cap_limit: 1, frequency_cap_duration: 10) }

      context 'with served impressions' do
        before do
          create(:submission, device_id: device.id, survey_id: survey.id, created_at: 5.minutes.ago)
        end

        it "serves the survey" do
          it_should_return_survey
        end
      end

      context 'with viewed impressions' do
        before do
          create(:submission, device_id: device.id, survey_id: survey.id, created_at: 5.minutes.ago, viewed_at: 5.minutes.ago)
        end

        it "does not serve the survey" do
          it_should_not_return_survey
        end

        context "when frequency cap is ignored at survey level" do
          before do
            survey.update(ignore_frequency_cap: true)
          end

          it "serves the survey" do
            it_should_return_survey
          end
        end

        context "when preview mode is enabled" do
          it "serves the survey" do
            it_should_return_survey(preview_mode: true)
          end
        end
      end
    end
  end
end
