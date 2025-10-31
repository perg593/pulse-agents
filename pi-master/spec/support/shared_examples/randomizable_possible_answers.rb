# frozen_string_literal: true

RSpec.shared_examples "randomizable possible answers" do
  let(:randomize) { nil }
  let(:question) { create(:question_without_possible_answers, survey: survey, question_type: question_type, randomize: randomize) }

  # Finds the possible answer ID on the DOM element
  # @param element - the element on the page to extract the id from
  def possible_answer_id_from_element(_element)
    raise NotImplementedError, "You must implement 'possible_answer_id_from_element' to use 'randomizable possible answers'"
  end

  before do
    # 10! = 3628800, so odds are we won't randomly
    # scramble them in position order
    10.times do |i|
      question.possible_answers << create(:possible_answer, question: question, position: i)
    end

    survey.questions << question
  end

  context "when randomizing all" do
    let(:randomize) { Question::RANDOMIZE_ALL }

    it "(probably) does not render the possible answers in position order" do
      expect(elements_in_position_order?).to be false
    end
  end

  context "when randomizing all except last" do
    let(:randomize) { Question::RANDOMIZE_ALL_EXCEPT_LAST }

    it "renders the last possible answer last" do
      expect(elements_in_position_order?).to be false

      expect(element_rendered_at_position?(answer_elements.last, question.possible_answers.pluck(:position).max)).to be true
    end
  end

  context "when randomization is inactive" do
    it "renders answers in position order" do
      expect(elements_in_position_order?).to be true
    end
  end

  private

  def elements_in_position_order?
    answer_elements.each_with_index do |answer_element, index|
      return false unless element_rendered_at_position?(answer_element, index)
    end

    true
  end

  def element_rendered_at_position?(element, position)
    rendered_possible_element_id = possible_answer_id_from_element(element)

    expected_possible_answer = question.possible_answers.find { |possible_answer| possible_answer.position == position }

    rendered_possible_element_id == expected_possible_answer.id
  end
end
