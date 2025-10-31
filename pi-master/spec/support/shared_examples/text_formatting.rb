# frozen_string_literal: true

# @param text_variable_symbol - The symbol of a lazy-loaded (i.e. "let") variable
#   representing the raw text to be formatted
RSpec.shared_examples "text formatting" do |text_variable_symbol|
  let(:element) { nil }

  shared_examples "formatted text" do |wrapper_character, open_tag, close_tag|
    context "when the message is wrapped in #{wrapper_character}" do
      let(text_variable_symbol) { "#{wrapper_character}#{FFaker::Lorem.phrase}#{wrapper_character}" }

      it "renders it wrapped in #{open_tag} markup" do
        formatted_output ="#{open_tag}#{send(text_variable_symbol).delete(wrapper_character)}#{close_tag}"

        expect(element).not_to be_nil
        expect(element.attribute("innerHTML").include?(formatted_output)).to be true
      end
    end

    context "when the message contains #{wrapper_character}" do
      let(text_variable_symbol) { "#{wrapper_character}#{FFaker::Lorem.phrase}" }

      it "renders it as-is" do
        formatted_output = send(text_variable_symbol)

        expect(element).not_to be_nil
        expect(element.attribute("innerHTML").include?(formatted_output)).to be true
      end
    end
  end

  describe "bold" do
    it_behaves_like "formatted text", "*", "<b>", "</b>"
  end

  describe "emphasis" do
    it_behaves_like "formatted text", "_", "<em>", "</em>"
  end

  describe "superscript" do
    it_behaves_like "formatted text", "^", "<sup>", "</sup>"
  end

  describe "subscript" do
    it_behaves_like "formatted text", "~", "<sub>", "</sub>"
  end
end
