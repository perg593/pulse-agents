# frozen_string_literal: true

RSpec.shared_examples "additional question content" do |question_type|
  describe "Additional Content" do
    let(:additional_content) { "<p>#{FFaker::Lorem.phrase}</p>" }

    before do
      @question = create(question_type, survey: survey, additional_content: additional_content)
    end

    context "when Additional Content is enabled" do
      before do
        @question.update(show_additional_content: true)
      end

      it "renders additional content" do
        expect(find_element({class: "_pi_additional_content"}).attribute('innerHTML')).to eq additional_content
      end

      context "when position is header" do
        before do
          @question.update(additional_content_position: :header)
        end

        it "has expected behaviour" do
          # "renders additional content above the question content"
          # Additional content comes before the answers container
          expect(find_element({xpath: "//div[@class='_pi_additional_content']/following-sibling::*[contains(@class, '_pi_question')]"})).not_to be_nil

          # "includes a data attribute"
          expect(find_element({class: "_pi_additional_content"}).attribute('data-position')).to eq "super-header"
        end
      end

      context "when position is between" do
        before do
          @question.update(additional_content_position: :between)
        end

        it "has expected behaviour" do
          # "renders additional content in between the question content and the answers container"
          # Additional content comes before the answers container
          expect(find_element({xpath: "//div[@class='_pi_additional_content']/following-sibling::*[@class='_pi_answers_container']"})).not_to be_nil

          # "includes a data attribute"
          expect(find_element({class: "_pi_additional_content"}).attribute('data-position')).to eq "header"
        end
      end

      context "when position is footer" do
        before do
          @question.update(additional_content_position: :footer)
        end

        it "has expected behaviour" do
          # "renders additional content in the footer"
          # Additional content comes after the answers container
          expect(find_element({xpath: "//div[@class='_pi_additional_content']/preceding-sibling::*[@class='_pi_answers_container']"})).not_to be_nil

          # "includes a data attribute"
          expect(find_element({class: "_pi_additional_content"}).attribute('data-position')).to eq "footer"
        end
      end
    end

    context "when Additional Content is disabled" do
      it "does not render additional content" do
        expect(find_element({class: "_pi_additional_content"})).to be_nil
      end
    end
  end
end
