# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'surveys_spec_helper')
include SurveysSpecHelper

describe "single_choice_question" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey_without_question, account: account, invitation_button_disabled: true) }
  let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account))) }

  it_behaves_like "additional question content", :single_choice_question
  it_behaves_like "additional text options", :single_choice_question
  it_behaves_like "answers per row", :single_choice_question

  describe "Menu answers" do
    describe "Dropdown labels" do
      subject { selected_dropdown_option.text }

      let(:single_choice_default_label) { nil }
      let(:question) { create(:question, button_type: :menu, single_choice_default_label: single_choice_default_label) }
      let(:dropdown_options) { find_all_elements({xpath: "//select[@class='_pi_select']/option"}) }
      let(:selected_dropdown_option) { dropdown_options.detect { |option| option.attribute("selected") } }

      before do
        survey.questions << question
      end

      context "when a custom label has been specified" do
        let(:single_choice_default_label) { FFaker::Lorem.phrase }

        it { is_expected.to eq single_choice_default_label }
      end

      context "when no custom label has been specified" do
        it { is_expected.to eq "Select an option" }
      end
    end
  end

  shared_examples "answer alignment" do |device|
    shared_examples "alignment by width type" do |width_type|
      let(:possible_answers_container) { find_element({class: "_pi_answers_container"}) }
      let(:widget_element) { find_element({id: "_pi_surveyWidget"}) }
      let(:question) { create(:single_choice_question, survey: survey, "#{device}_width_type" => width_type, "answers_alignment_#{device}" => answers_alignment) }
      let(:answers_alignment) { nil }

      before do
        survey.questions << question
      end

      def it_stores_alignment_in_data_attributes
        alignment_data = answers_alignment.to_s.gsub("_", "-")

        expect(possible_answers_container.attribute("data-answers-alignment")).to eq alignment_data
        expect(widget_element.attribute("data-answers-alignment")).to eq alignment_data
      end

      it "stores layout in data attribute" do
        expect(possible_answers_container.attribute("data-answers-layout")).to eq width_type.to_s
        expect(widget_element.attribute("data-answers-layout")).to eq width_type.to_s
      end

      # TODO: Review CSS in survey.coffee. It seems a bit redundant
      #
      # These two rules will be overridden by subsequent data-answers-alignment rules.
      # The only way they'd be applied is if the alignment was null, which doesn't seem possible
      #
      # div[data-answers-layout='fixed']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      # ul[data-answers-layout='fixed'] {
      #    justify-content: flex-start;
      # }
      #
      # div[data-answers-layout='variable']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      # ul[data-answers-layout='variable'] {
      #    justify-content: center;
      # }
      #
      #
      # The only <ul> with data-answers-alignment is pi_answers_container, so the first selector seems a bit redundant
      #
      # div[data-answers-alignment='left']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      # ul[data-answers-alignment='left'] {
      describe "alignment" do
        subject { possible_answers_container.style("justify-content") }

        context "when left" do
          let(:answers_alignment) { :left }

          it "stores the alignment in data attributes" do
            it_stores_alignment_in_data_attributes
            expect(subject).to eq "flex-start"
          end
        end

        context "when center" do
          let(:answers_alignment) { :center }

          it "stores the alignment in data attributes" do
            it_stores_alignment_in_data_attributes
            expect(subject).to eq "center"
          end
        end

        context "when right" do
          let(:answers_alignment) { :right }

          it "stores the alignment in data attributes" do
            it_stores_alignment_in_data_attributes
            expect(subject).to eq "flex-end"
          end
        end

        context "when space_between" do
          let(:answers_alignment) { :space_between }

          it "stores the alignment in data attributes" do
            it_stores_alignment_in_data_attributes
            expect(subject).to eq "space-between"
          end
        end

        context "when space_around" do
          let(:answers_alignment) { :space_around }

          it "stores the alignment in data attributes" do
            it_stores_alignment_in_data_attributes
            expect(subject).to eq "space-around"
          end
        end

        context "when space_evenly" do
          let(:answers_alignment) { :space_evenly }

          it "stores the alignment in data attributes" do
            it_stores_alignment_in_data_attributes
            expect(subject).to eq "space-evenly"
          end
        end
      end
    end

    it_behaves_like "alignment by width type", :variable
    it_behaves_like "alignment by width type", :fixed
  end

  describe "Standard button answers" do
    it_behaves_like "answer alignment", "desktop"

    it_behaves_like "answer alignment", "mobile" do
      let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account)), user_agent: "android mobile") }
    end
  end

  describe "before/after text" do
    subject { find_header_element.attribute("class") }

    let(:before_question_text) { nil }
    let(:after_question_text) { nil }
    let(:question) { create(:question, before_question_text: before_question_text, after_question_text: after_question_text, survey: survey) }

    before do
      survey.questions << question
    end

    context "with a question with 'before text'" do
      let(:before_question_text) { FFaker::Lorem.word }
      let(:additional_question_text_header_id) { "_pi_header_before_#{question.id}" }

      it { is_expected.to eq "_pi_header pi_header_before" }
    end

    context "with a question with 'after text'" do
      let(:after_question_text) { FFaker::Lorem.word }
      let(:additional_question_text_header_id) { "_pi_header_after_#{question.id}" }

      it { is_expected.to eq "_pi_header pi_header_after" }
    end
  end

  # Make sure empty answer alert element doesn't appear in the DOM tree
  # to avoid style impacts on one-at-a-time surveys
  describe "DOM tree" do
    before do
      survey.questions << create(:single_choice_question, survey: survey)
      find_element({class: "_pi_answers_container"})
    end

    let(:alert_label_containers) { find_all_elements({class: "_pi_single_choice_question_label_container"}) }
    let(:empty_answer_alerts) { find_all_elements({class: "_pi_single_choice_question_empty_answer_alert"}) }

    it_behaves_like "alert containers"
  end

  describe "Answer images" do
    let(:answer_container_selector) { "//ul[@class='_pi_answers_container']" }
    let(:answer_selector) { "li[@class='with-image']" }
    let(:link_selector) { "a[@class='with-image']" }

    let(:answer_list_item) { find_element({xpath: "#{answer_container_selector}/#{answer_selector}"}) }
    let(:answer_link) { find_element({xpath: "#{answer_container_selector}/#{answer_selector}/#{link_selector}"}) }
    let(:answer_image_element) { find_element({xpath: "#{answer_container_selector}/#{answer_selector}/#{link_selector}/img"}) }

    let(:answer_image) do
      answer_image_file = Rack::Test::UploadedFile.new("#{Rails.root}/spec/file_fixtures/background.jpg", "image/jpeg")
      AnswerImage.create(image: answer_image_file, imageable: account)
    end

    let(:question) { create(:question_without_possible_answers, survey: survey) }
    let(:possible_answer) { create(:possible_answer, question: question, answer_image: answer_image) }

    before do
      question.possible_answers << possible_answer
      survey.questions << question

      driver.current_url
      sleep(1)
    end

    describe "alt text" do
      subject { answer_image_element.attribute("alt") }

      let(:possible_answer) { create(:possible_answer, question: question, answer_image: answer_image, image_alt: image_alt) }
      let(:image_alt) { "" }

      context "when alt text is not provided" do
        it { is_expected.to eq "" }
      end

      context "when alt text is provided" do
        let(:image_alt) { FFaker::Lorem.word }

        it { is_expected.to eq image_alt }
      end
    end

    # "width" or "height"
    shared_examples "answer image dimensions" do |dimension|
      let(:fixture_image_width) { "1182" }
      let(:fixture_image_height) { "682" }
      let(:fixture_image_dimension) { dimension == "width" ? fixture_image_width : fixture_image_height }

      # TODO: Support px or pixels
      describe dimension do
        subject { answer_image_element.attribute(dimension) }

        context "when mobile" do
          let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account)), user_agent: "android mobile") }
          let(:possible_answer) { create(:possible_answer, question: question, answer_image: answer_image, "image_#{dimension}_mobile" => image_dimension_mobile) }
          let(:image_dimension_mobile) { nil }

          context "when image_#{dimension}_mobile is provided" do
            let(:image_dimension_mobile) { "100" }

            it { is_expected.to eq image_dimension_mobile }
          end

          context "when image_#{dimension}_mobile is not provided" do
            it { is_expected.to eq fixture_image_dimension }
          end
        end

        context "when tablet" do
          let(:driver) { @driver = setup_driver(html_test_file(html_test_page(account)), user_agent: "iPad") }
          let(:possible_answer) { create(:possible_answer, question: question, answer_image: answer_image, "image_#{dimension}_tablet" => image_dimension_tablet) }
          let(:image_dimension_tablet) { nil }

          context "when image_#{dimension}_tablet is provided" do
            let(:image_dimension_tablet) { "100" }

            it { is_expected.to eq image_dimension_tablet }
          end

          context "when image_#{dimension}_tablet is not provided" do
            it { is_expected.to eq fixture_image_dimension }
          end
        end

        context "when desktop" do
          let(:possible_answer) { create(:possible_answer, question: question, answer_image: answer_image, "image_#{dimension}": image_dimension) }
          let(:image_dimension) { nil }

          context "when image_#{dimension} is provided" do
            let(:image_dimension) { "100" }

            it { is_expected.to eq image_dimension }
          end

          context "when image_#{dimension} is not provided" do
            it { is_expected.to eq fixture_image_dimension }
          end
        end
      end
    end

    it_behaves_like "answer image dimensions", "width"
    it_behaves_like "answer image dimensions", "height"

    describe "image toggling" do
      let(:answer_label_elements) { find_all_elements({xpath: "#{answer_container_selector}/#{answer_selector}/#{link_selector}/label"}) }

      def it_renders_the_image
        expect(answer_list_item).not_to be_nil
        expect(answer_link).not_to be_nil
        expect(answer_image_element).not_to be_nil
        expect(answer_image_element.attribute("src")).to eq image_url(answer_image.id, answer_image.image.identifier)
      end

      context "when image only" do
        let(:question) { create(:question_without_possible_answers, survey: survey, image_settings: :image_only) }

        it "renders the image" do
          it_renders_the_image
        end

        it "renders no text" do
          expect(answer_label_elements).to be_nil
        end
      end

      context "when image and text" do
        let(:question) { create(:question_without_possible_answers, survey: survey, image_settings: :text_and_image) }

        it "renders the image and the text" do
          it_renders_the_image
          expect(answer_label_elements).not_to be_nil
        end
      end

      context "when nothing specified" do
        it "renders the image and the text" do
          it_renders_the_image
          expect(answer_label_elements).not_to be_nil
        end
      end
    end
  end

  it_behaves_like "randomizable possible answers" do
    let(:question_type) { :single_choice_question }
    let(:answer_elements) { find_all_elements({xpath: "//*[@class='_pi_answers_container']//a"}) }

    def possible_answer_id_from_element(element)
      element.attribute("data-answer-id").to_i
    end
  end

  private

  # TODO: Make available elsewhere
  def image_url(image_id, image_name)
    return unless image_id

    "https://cdn.pulseinsights.com/images/answer_image/#{image_id}/#{image_name}"
  end

  def find_header_element
    find_element({id: additional_question_text_header_id})
  end
end
