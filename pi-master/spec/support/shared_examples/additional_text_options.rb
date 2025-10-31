# frozen_string_literal: true

# Tests for labels that appear before and/or after the possible answer container
RSpec.shared_examples "additional text options" do |question_type|
  describe "Additional Text" do
    let(:question) { create(question_type, survey: survey) }

    before do
      survey.questions << question
      driver.current_url # Waking up the lazy-loaded driver
      sleep(1)
    end

    shared_examples "text" do |position|
      describe "#{position} answer text" do
        let(:container_path) { "//div[@class='_pi_scale_container _pi_scale_container_#{position}']" }
        let(:container) { find_element({xpath: container_path}) }
        let(:additional_text) { nil }
        let(:question) { create(question_type, survey: survey, additional_text: additional_text) }

        context "when #{position} answer text is absent" do
          it "does not render the container" do
            expect(container).to be_nil
          end
        end

        context "when answer text is present" do
          let(:additional_text) { { "#{position}_answers_count" => answer_items.length, "#{position}_answers_items" => answer_items} }
          let(:answer_item_selector) { "#{container_path}/div[contains(@class, '_pi_scale')]" }
          let(:answer_items) { [FFaker::Lorem.phrase] }

          context "when one #{position} answer item is present" do
            let(:answer_items) { [FFaker::Lorem.phrase] }

            it "renders the item" do
              it_renders_items
            end
          end

          context "when two #{position} answer items are present" do
            let(:answer_items) { [FFaker::Lorem.phrase, FFaker::Lorem.phrase] }

            it "renders all items" do
              it_renders_items
            end
          end

          context "when three #{position} answer items are present" do
            let(:answer_items) { [FFaker::Lorem.phrase, FFaker::Lorem.phrase, FFaker::Lorem.phrase] }

            it "renders all items" do
              it_renders_items
            end
          end

          it "renders the container" do
            expect(container).not_to be_nil
            expect(container.attribute('data-scale-items')).to eq question.additional_text["#{position}_answers_count"].to_s

            sibling_selector = "#{position == 'before' ? 'following-sibling' : 'preceding-sibling'}::*[@class='_pi_answers_container']"
            expect(find_element({xpath: "#{container_path}/#{sibling_selector}"})).not_to be_nil
          end
        end

        def item_class(items, item_index)
          if items.length == 1
            "_pi_scale_middle"
          elsif items.length > 1
            case item_index
            when 0
              "_pi_scale_first"
            when items.length - 1
              "_pi_scale_last"
            else
              "_pi_scale_middle"
            end
          end
        end

        def it_renders_items
          items = find_all_elements({xpath: answer_item_selector})
          expect(items.count).to eq answer_items.length

          items.each_with_index do |item, item_index|
            expect(item).to have_class("_pi_scale")
            expect(item).to have_class(item_class(items, item_index))

            expect(item.text).to eq answer_items[item_index]
          end
        end
      end
    end

    it_behaves_like "text", 'before'
    it_behaves_like "text", 'after'

    # TODO: test both at once
  end
end
