# frozen_string_literal: true

# Tests that answers_per_row_desktop and answers_per_row_mobile
# settings are respected by the survey widget
RSpec.shared_examples "answers per row" do |question_type|
  describe "answers per row" do
    let(:answers_per_row_desktop) { nil }
    let(:answers_per_row_mobile) { nil }
    let(:question) { create(question_type, survey: survey, answers_per_row_desktop: answers_per_row_desktop, answers_per_row_mobile: answers_per_row_mobile) }
    let(:answers_per_row) { 2 }

    before do
      (answers_per_row * 2).times { question.possible_answers << create(:possible_answer, question: question) }
      survey.questions << question

      answer_elements = find_all_elements({class: "_pi_answers_container li"})
      @num_answers_per_top = answer_elements.map { |answer_element| answer_element.attribute('offsetTop') }.tally
    end

    context "when desktop" do
      let(:answers_per_row_desktop) { answers_per_row }

      it "has no more than two answers per row" do
        expect(@num_answers_per_top.values.max).to eq answers_per_row_desktop
      end
    end

    context "when mobile" do
      let(:driver) { @driver ||= setup_driver(html_test_file(html_test_page(account)), user_agent: "android mobile") }
      let(:answers_per_row_mobile) { answers_per_row }

      it "has no more than two answers per row" do
        expect(@num_answers_per_top.values.max).to eq answers_per_row_mobile
      end
    end
  end
end
