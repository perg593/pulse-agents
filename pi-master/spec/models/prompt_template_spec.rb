# frozen_string_literal: true

require 'spec_helper'

describe PromptTemplate do
  describe "validations" do
    it "is valid with valid attributes" do
      prompt_template = build(:prompt_template)

      expect(prompt_template).to be_valid
    end

    it "requires a name" do
      prompt_template = build(:prompt_template, name: nil)

      expect(prompt_template).not_to be_valid
      expect(prompt_template.errors[:name]).to include("can't be blank")
    end

    it "requires unique names" do
      create(:prompt_template, name: "Test Template")
      duplicate = build(:prompt_template, name: "Test Template")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "requires content" do
      prompt_template = build(:prompt_template, content: nil)

      expect(prompt_template).not_to be_valid
      expect(prompt_template.errors[:content]).to include("can't be blank")
    end

    it "allows creating multiple default templates (callback handles swapping)" do
      first_default = create(:prompt_template, :default, name: "First Default")
      second_default = create(:prompt_template, :default, name: "Second Default")

      first_default.reload
      expect(first_default.is_default?).to be false
      expect(second_default.is_default?).to be true
    end

    it "allows updating a default template" do
      default_template = create(:prompt_template, :default, name: "Default Template")
      default_template.name = "Updated Default Template"
      expect(default_template).to be_valid
    end
  end

  describe "scopes" do
    describe ".default" do
      let!(:default_template) { create(:prompt_template, :default, name: "Default") }

      before do
        create(:prompt_template, name: "Regular")
      end

      it "returns only default templates" do
        expect(described_class.default).to contain_exactly(default_template)
      end
    end
  end

  describe "callbacks" do
    it "swaps default status when setting a new default" do
      first_default = create(:prompt_template, :default, name: "First Default")
      second_template = create(:prompt_template, name: "Second Template")

      # Set the second template as default - should unset the first
      second_template.update!(is_default: true)
      first_default.reload

      expect(first_default.is_default?).to be false
      expect(second_template.is_default?).to be true
    end

    it "doesn't change other templates when setting non-default" do
      default_template = create(:prompt_template, :default, name: "Default")
      regular_template = create(:prompt_template, name: "Regular")

      regular_template.update!(name: "Updated Regular")
      default_template.reload

      expect(default_template.is_default?).to be true
    end
  end
end
