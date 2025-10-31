# frozen_string_literal: true

RSpec.shared_examples "submit button label" do
  subject { find_element({class: submit_button_class_selector}).attribute(:value) }

  before do
    @question = question || create(question_type, survey: survey)
  end

  context "when a custom submit label has been specified" do
    let(:custom_submit_label) { FFaker::Lorem.word }

    before do
      @question.update(submit_label: custom_submit_label)
    end

    it { is_expected.to eq custom_submit_label }
  end

  context "when no custom submit label has been specified" do
    it { is_expected.to eq "Submit" }
  end
end
