# frozen_string_literal: true
require 'spec_helper'

describe QrveyApplication do
  describe "Associations" do
    it { is_expected.to have_many(:qrvey_datasets) }
  end

  describe "Qrvey API" do
    let(:account) do
      a = create(:account)
      a.register_with_qrvey

      a
    end

    let(:qrvey_user) { account.qrvey_user }

    context "when record is created" do
      before do
        @qrvey_application = create(:qrvey_application, qrvey_user: qrvey_user)
      end

      it "queues Qrvey::ApplicationWorker" do
        expect(Qrvey::ApplicationWorker).to have_enqueued_sidekiq_job(@qrvey_application.id)
      end
    end

    describe "#register_with_qrvey" do
      let(:dummy_qrvey_application_id) { "some_qrvey_application_id" }
      let(:dummy_qrvey_user_id) { "some_qrvey_user_id" }

      before do
        qrvey_user.update(qrvey_user_id: dummy_qrvey_user_id)
      end

      context "when qrvey_application_id is present" do
        let(:qrvey_application) { create(:qrvey_application, qrvey_application_id: dummy_qrvey_application_id, qrvey_user: qrvey_user) }

        it "does not communicate with Qrvey" do
          qrvey_application.register_with_qrvey
          # If it did make an API call then WebMock would fail because we haven't stubbed the call.
        end
      end

      context "when qrvey_application_id is not present" do
        let(:qrvey_application) { create(:qrvey_application, qrvey_user: qrvey_user) }

        before do
          body = {
            name: "#{account.identifier} #{account.name} Tenant App",
            description: "A tenant application for #{account.name}. ID: #{account.id}. #{account.identifier}"
          }

          allow(QrveyClient).to receive(:create_application).with(dummy_qrvey_user_id, body).and_return({"appid" => dummy_qrvey_application_id})

          body = {
            isPublic: false,
            groupIds: ["EhIqB-JdL"], # TenantAppAdmin
            userIds: [],
            appId: dummy_qrvey_application_id
          }

          allow(QrveyClient).to receive(:share_application).with(dummy_qrvey_application_id, body).and_return(true)

          qrvey_application.register_with_qrvey
        end

        it "fills in qrvey_application_id" do
          expect(qrvey_application.qrvey_application_id).to eq dummy_qrvey_application_id
        end

        it "marks shared as true" do
          expect(qrvey_application.shared).to be true
        end
      end
    end
  end
end
