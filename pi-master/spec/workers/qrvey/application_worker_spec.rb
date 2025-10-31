# frozen_string_literal: true
require 'spec_helper'
require_relative "../../../lib/qrvey_client/qrvey_client"

describe Qrvey::ApplicationWorker do
  let(:account) do
    a = create(:account)
    a.register_with_qrvey

    a
  end

  it "calls :register_with_qrvey on the QrveyApplication with the provided ID" do
    @qrvey_application = create(:qrvey_application, qrvey_user: account.qrvey_user)
    allow(QrveyApplication).to receive(:find).and_return(@qrvey_application)

    allow(@qrvey_application).to receive(:register_with_qrvey)

    # Confirm that complicated function is called.
    expect(@qrvey_application).to receive(:register_with_qrvey).exactly(1).times

    described_class.new.perform(@qrvey_application.id)
  end
end
