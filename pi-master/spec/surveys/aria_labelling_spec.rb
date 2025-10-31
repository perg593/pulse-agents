# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "aria labelling" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey_without_question, account: account, invitation_button_disabled: true) }
  let(:answers_container_class) { "_pi_answers_container" }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 10) } # seconds

  context "with a question without any additional text" do
    before do
      @question = create(:question, survey_id: survey.id)
      @driver = setup_driver(html_test_file(html_test_page(account)))
    end

    it "renders aria labels" do
      label_element_id = "_pi_question_#{@question.id}"

      wait.until { @driver.find_element(id: label_element_id) }

      answers_container = @driver.find_element(class: answers_container_class)
      expect(answers_container.attribute('aria-labelledby')).to eq label_element_id
    end
  end

  def it_renders_all_in_correct_order(label_element_ids)
    wait_for_question_to_load

    answers_container = @driver.find_element(class: answers_container_class)
    expect(answers_container.attribute('aria-labelledby')).to eq label_element_ids.join(" ")
  end

  def wait_for_question_to_load
    wait.until { @driver.find_element(id: question_element_id) }
  end

  def question_element_id
    "_pi_question_#{@question.id}"
  end

  context "with a question with 'before text'" do
    before do
      @question = create(:question, before_question_text: FFaker::Lorem.word, survey_id: survey.id)
      @driver = setup_driver(html_test_file(html_test_page(account)))
    end

    it "renders aria labels" do
      label_element_ids = ["_pi_header_before_#{@question.id}", question_element_id]
      it_renders_all_in_correct_order(label_element_ids)
    end
  end

  context "with a question with 'after text'" do
    before do
      @question = create(:question, after_question_text: FFaker::Lorem.word, survey_id: survey.id)
      @driver = setup_driver(html_test_file(html_test_page(account)))
    end

    it "renders aria labels" do
      label_element_ids = [question_element_id, "_pi_header_after_#{@question.id}"]
      it_renders_all_in_correct_order(label_element_ids)
    end
  end

  context "with a question with both 'before text' and 'after text'" do
    before do
      @question = create(:question, before_question_text: FFaker::Lorem.word, after_question_text: FFaker::Lorem.word, survey_id: survey.id)
      @driver = setup_driver(html_test_file(html_test_page(account)))
    end

    it "renders aria labels" do
      label_element_ids = ["_pi_header_before_#{@question.id}", question_element_id, "_pi_header_after_#{@question.id}"]
      it_renders_all_in_correct_order(label_element_ids)
    end
  end

  context "with a question with 'menu' (i.e. 'select' tag) style possible answers" do
    let(:answers_container_class) { "_pi_select" }

    before do
      @question = create(:question, survey_id: survey.id, button_type: "menu")
      @driver = setup_driver(html_test_file(html_test_page(account)))
    end

    it "renders aria labels" do
      label_element_ids = [question_element_id]
      it_renders_all_in_correct_order(label_element_ids)
    end
  end

  context "with a multiple-choice question" do
    before do
      @question = create(:multiple_choices_question, survey_id: survey.id)
      @driver = setup_driver(html_test_file(html_test_page(account)))
    end

    it "renders aria labels" do
      label_element_ids = [question_element_id]
      it_renders_all_in_correct_order(label_element_ids)
    end
  end

  context "with a free-text question" do
    let(:answers_container_class) { "_pi_free_text_question_field" }

    before do
      @question = create(:free_text_question, survey_id: survey.id)
      @driver = setup_driver(html_test_file(html_test_page(account)))
    end

    it "renders aria labels" do
      label_element_ids = [question_element_id]
      it_renders_all_in_correct_order(label_element_ids)
    end
  end
end
