# frozen_string_literal: true
require 'spec_helper'

describe Tag do
  let(:question) { create(:free_text_question, tag_automation_worker_enabled: true) }

  describe '::placeholder' do
    it 'returns a Tag object with the specified name and color' do
      expect(described_class.placeholder(question).name).to eq 'Unable to AutoTag'
      expect(described_class.placeholder(question).color).to eq 'black'
    end
  end

  describe "name" do
    ["a  ", "  a", "  a"].each do |name|
      context "when name contains surrounding whitespace '#{name}'" do
        before do
          @tag = create(:tag, name: name)
        end

        it "trims surrounding whitespace" do
          expect(@tag.name).to eq "a"
        end
      end
    end
  end
end
