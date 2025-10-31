# frozen_string_literal: true

RSpec.shared_examples "alert containers" do
  it "has expected behaviour" do
    # "doesn't have a label container element"
    expect(alert_label_containers).to be_nil

    # "doesn't have an empty answer alert element"
    expect(empty_answer_alerts).to be_nil
  end
end
