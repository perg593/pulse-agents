# frozen_string_literal: true
require 'spec_helper'

describe QrveyUser do
  describe "Qrvey API" do
    let(:account) do
      a = create(:account)
      a.register_with_qrvey

      a
    end

    let(:qrvey_user) { account.qrvey_user }

    context "when record is created" do
      it "queues Qrvey::UserWorker" do
        expect(Qrvey::UserWorker).to have_enqueued_sidekiq_job(qrvey_user.id)
      end
    end

    describe "#register_with_qrvey" do
      let(:dummy_qrvey_user_id) { "some_qrvey_user_id" }

      context "when qrvey_user_id is present" do
        before do
          qrvey_user.update(qrvey_user_id: dummy_qrvey_user_id)
          @stubbed_user_creation = stub_request(:any, "https://phbxd.qrveyapp.com/devapi/v4/core/user").
                                   to_return(status: 200, body: { userid: "foo" }.to_json, headers: {})

          qrvey_user.register_with_qrvey
        end

        it "does not communicate with Qrvey" do
          expect(@stubbed_user_creation).not_to have_been_made
        end

        it "does not change the registered qrvey_user_id" do
          expect(qrvey_user.qrvey_user_id).to eq(dummy_qrvey_user_id)
        end
      end

      context "when qrvey_user_id is not present" do
        before do
          body = {
            first_name: "Pablo",
            last_name: "Insights",
            email: "qrveyserviceuser+#{qrvey_user.account.id}@pulseinsights.com",
            password: qrvey_user.password,
            groupList: [
              {
                groupid: "c-WUhuurn",
                name: "Service User"
              }
            ]
          }

          allow(QrveyClient).to receive(:create_user).with(body).and_return(dummy_qrvey_user_id)
        end

        it "fills in qrvey_user_id" do
          qrvey_user.register_with_qrvey

          expect(qrvey_user.qrvey_user_id).to eq dummy_qrvey_user_id
        end
      end
    end
  end
end
