# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "One at a time survey" do
  let(:account) { create(:account) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  describe "survey flow" do
    let(:survey) { create(:survey_without_question, account: account, invitation: nil) } # We've tested invitations elsewhere
    let(:thank_you_element) { find_element({xpath: "//div[@class='_pi_thankYouSurvey']" }) }
    let(:first_possible_answer) { survey.questions.first.possible_answers.sort_by_position.first }
    let(:last_possible_answer) { survey.questions.first.possible_answers.sort_by_position.last }

    let(:first_question) { create(:question, survey: survey, position: 0) }
    let(:last_question) { create(:question, survey: survey, position: 1) }

    before do
      survey.questions << first_question
      survey.questions << last_question
    end

    context "when no question routing is configured" do
      let(:first_question) { create(:question, survey: survey) }

      context "when the first question is answered" do
        before do
          answer_the_question(first_question)
        end

        it "ends the survey" do
          expect(thank_you_element).not_to be_nil
        end
      end
    end

    context "when single choice possible answer routing is configured" do
      let(:first_question) { create(:single_choice_question, survey: survey) }

      before do
        first_possible_answer.update(next_question_id: last_question.id)
      end

      context "when the first question is answered" do
        before do
          answer_the_question(first_question)
        end

        it "follows question routing" do
          it_renders_the_question(last_question)
          it_only_renders_one_question
        end
      end
    end

    # Only the last possible answer supports routing
    context "when multiple choice possible answer routing is configured" do
      let(:first_question) { create(:multiple_choices_question, survey: survey) }

      before do
        last_possible_answer.update(next_question_id: last_question.id)
      end

      context "when the first question is answered" do
        before do
          answer_the_question(first_question, answer_last_possible_answer: true)
        end

        it "follows question routing" do
          it_renders_the_question(last_question)
          it_only_renders_one_question
        end
      end
    end

    context "when multiple choice question routing is configured" do
      let(:first_question) { create(:multiple_choices_question, survey: survey, next_question_id: last_question.id, position: 0) }

      context "when the first question is answered" do
        before do
          answer_the_question(first_question)
        end

        it "follows question routing" do
          it_renders_the_question(last_question)
          it_only_renders_one_question
        end
      end
    end

    context "when both possible answer-level and question-level routing is configured" do
      let(:first_question) { create(:multiple_choices_question, survey: survey) }

      before do
        last_possible_answer.update(next_question_id: last_question.id)
        first_question.update(next_question_id: first_question.id)
      end

      context "when all possible answers are selected" do
        before do
          possible_answer_elements = find_all_elements({class: "_pi-control-checkbox"})
          possible_answer_elements.each(&:click)

          submit_button = find_element({class: '_pi_multiple_choices_question_submit_button'})
          submit_button.click
        end

        it "follows possible answer-level routing" do
          it_renders_the_question(last_question)
          it_only_renders_one_question
        end
      end
    end

    context "when free text question routing is configured" do
      let(:first_question) { create(:free_text_question, survey: survey, free_text_next_question_id: last_question.id, position: 0) }

      context "when the first question is answered" do
        before do
          answer_the_question(first_question)
        end

        it "follows question routing" do
          it_renders_the_question(last_question)
          it_only_renders_one_question
        end
      end
    end

    context "when slider question routing is configured" do
      let(:first_question) { create(:slider_question, slider_submit_button_enabled: false, survey: survey) }

      before do
        first_possible_answer.update(next_question_id: last_question.id)
      end

      context "when the first question is answered" do
        before do
          answer_the_question(first_question)
        end

        it "follows question routing" do
          it_renders_the_question(last_question)
          it_only_renders_one_question
        end
      end
    end

    context "when NPS question routing is configured" do
      let(:first_question) { create(:nps_question, survey: survey) }

      before do
        first_possible_answer.update(next_question_id: last_question.id)
      end

      context "when the first question is answered" do
        before do
          answer_the_question(first_question)
        end

        it "follows question routing" do
          it_renders_the_question(last_question)
          it_only_renders_one_question
        end
      end
    end
  end

  # JAWs related
  describe "Focus behaviour" do
    subject { active_element }

    let(:active_element) { driver.execute_script("return document.activeElement") }

    let(:survey) { create(:survey_without_question, account: account, invitation: nil) } # We've tested invitations elsewhere

    let(:first_question) { create(:free_text_question, survey: survey, position: 0, free_text_next_question_id: last_question.id) }
    let(:last_question) { create(:question, survey: survey, position: 1) }
    let(:by_clicking) { false }
    let(:body) { find_element({xpath: "//body"}) }

    before do
      survey.questions << first_question
      survey.questions << last_question

      answer_the_question(first_question, by_clicking: by_clicking)

      sleep(1) # give the last question time to load
    end

    context "when a single choice question is rendered" do
      context "when not clicking" do
        let(:by_clicking) { false }
        let(:last_question) { create(:single_choice_question, survey: survey, position: 1) }

        it { is_expected.to eq find_all_elements({xpath: "//*[@class='_pi_answers_container']/li/a"})[0] }

        context "when menu-type" do
          let(:last_question) { create(:single_choice_question, survey: survey, button_type: :menu, position: 1) }

          it { is_expected.to eq find_all_elements({class: "_pi_select"})[0] }
        end
      end

      context "when clicking" do
        let(:by_clicking) { true }

        it { is_expected.to eq body }

        context "when menu-type" do
          let(:last_question) { create(:single_choice_question, survey: survey, button_type: :menu, position: 1) }

          it { is_expected.to eq body }
        end
      end
    end

    context "when a multiple choice question is rendered" do
      let(:last_question) { create(:multiple_choices_question, survey: survey, position: 1) }

      context "when not clicking" do
        let(:by_clicking) { false }

        it { is_expected.to eq find_all_elements({class: "_pi_checkbox"})[0] }
      end

      context "when clicking" do
        let(:by_clicking) { true }

        it { is_expected.to eq body }
      end
    end

    context "when a free text question is rendered" do
      let(:last_question) { create(:free_text_question, survey: survey, position: 1) }

      context "when not clicking" do
        let(:by_clicking) { false }

        it { is_expected.to eq find_all_elements({class: "_pi_free_text_question_field"})[0] }
      end

      context "when clicking" do
        let(:by_clicking) { true }

        it { is_expected.to eq body }
      end
    end

    context "when a slider question is rendered" do
      let(:last_question) { create(:slider_question, survey: survey, position: 1) }

      context "when not clicking" do
        it { is_expected.to eq find_all_elements({class: "_pi_hidden_slider"})[0] }
      end

      context "when clicking" do
        let(:by_clicking) { true }

        it { is_expected.to eq body }
      end
    end

    context "when a custom content question is rendered" do
      let(:last_question) { create(:custom_content_question, survey: survey, position: 1) }

      context "when not clicking" do
        let(:by_clicking) { false }

        it { is_expected.to eq find_all_elements({class: "_pi_question_custom_content_question"})[0] }
      end

      context "when clicking" do
        let(:by_clicking) { true }

        it { is_expected.to eq body }
      end
    end

    context "when a thank you card is rendered" do
      before do
        answer_the_question(last_question, by_clicking: by_clicking)
        sleep(1) # give the thank you time to load
      end

      context "when not clicking" do
        let(:by_clicking) { false }

        it { is_expected.to eq find_all_elements({class: "_pi_thankYouSurvey"})[0] }
      end

      context "when clicking" do
        let(:by_clicking) { true }

        it { is_expected.to eq body }
      end
    end
  end

  def it_only_renders_one_question
    expect(find_all_elements({class: "_pi_question"}).count).to eq 1
  end

  def answer_free_text_question(by_clicking: true)
    free_text_text_field = find_element({class: "_pi_free_text_question_field"})
    free_text_text_field.send_keys(FFaker::Lorem.phrase)

    submit_button = find_element({class: '_pi_free_text_question_submit_button'})

    if by_clicking
      submit_button.click
    else
      submit_button.send_keys(:return)
    end
  end

  def answer_slider_question(by_clicking: true)
    if by_clicking
      selectable = find_all_elements({class: "noUi-value"})[0]
      selectable.click
    else
      selectable = find_all_elements({class: "_pi_hidden_slider"})[0]
      selectable.send_keys(:arrow_left)
    end
  end

  def answer_multiple_choices_question(answer_last_possible_answer: false, by_clicking: true)
    possible_answer_elements = find_all_elements({class: "_pi-control-checkbox"})
    possible_answer_to_select = answer_last_possible_answer ? possible_answer_elements.last : possible_answer_elements.first
    possible_answer_to_select.click

    submit_button = find_element({class: '_pi_multiple_choices_question_submit_button'})

    if by_clicking
      submit_button.click
    else
      submit_button.send_keys(:return)
    end
  end

  def answer_single_choice_question(answer_last_possible_answer: false, by_clicking: true)
    possible_answer_elements = find_all_elements({xpath: "//*[@class='_pi_answers_container']/li/a"})
    possible_answer_to_select = answer_last_possible_answer ? possible_answer_elements.last : possible_answer_elements.first

    if by_clicking
      possible_answer_to_select.click
    else
      possible_answer_to_select.send_keys(:return)
    end
  end

  def answer_the_question(question, answer_last_possible_answer: false, by_clicking: true)
    case question.question_type.to_sym
    when :single_choice_question
      answer_single_choice_question(answer_last_possible_answer: answer_last_possible_answer, by_clicking: by_clicking)
    when :multiple_choices_question
      answer_multiple_choices_question(answer_last_possible_answer: answer_last_possible_answer, by_clicking: by_clicking)
    when :free_text_question
      answer_free_text_question(by_clicking: by_clicking)
    when :slider_question
      answer_slider_question(by_clicking: by_clicking)
    else
      puts "UNHANDLED QUESTION TYPE!!ONE!!!"
    end
  end
end
