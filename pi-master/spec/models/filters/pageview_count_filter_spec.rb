# frozen_string_literal: true
require 'spec_helper'

describe Filters::PageviewCountFilter do
  let(:value) { 5 }

  describe "constructor" do
    it "returns a PageviewCountFilter object" do
      %w(equal_to greater_than_or_equal_to less_than_or_equal_to less_than greater_than).each do |comparator|
        filter = described_class.new(comparator, value)

        expect(filter.comparator).to eq(comparator)
        expect(filter.value).to eq(value)
      end
    end

    it "fails if comparator is not an accepted value" do
      assert_raises(ArgumentError) { described_class.new('foo', value) }
    end

    it "fails if value is not a positive integer" do
      [-1, 0.5, '2'].each do |invalid_value|
        assert_raises(ArgumentError) { described_class.new('equal_to', invalid_value) }
      end
    end

    it "accepts zero" do
      described_class.new('equal_to', 0)
    end
  end

  describe "to_sql" do
    context "when comparator is less_than" do
      let(:comparator) { "less_than" }

      it "returns an sql string representing less than value" do
        filter = described_class.new(comparator, value)
        expect(filter.to_sql).to eq("submissions.pageview_count < #{value}")
      end
    end

    context "when comparator is less_than_or_equal_to" do
      let(:comparator) { "less_than_or_equal_to" }

      it "returns an sql string representing less than or equal to value" do
        filter = described_class.new(comparator, value)
        expect(filter.to_sql).to eq("submissions.pageview_count <= #{value}")
      end
    end

    context "when comparator is equal_to" do
      let(:comparator) { "equal_to" }

      it "returns an sql string representing equal to value" do
        filter = described_class.new(comparator, value)
        expect(filter.to_sql).to eq("submissions.pageview_count = #{value}")
      end
    end

    context "when comparator is greater_than_or_equal_to" do
      let(:comparator) { "greater_than_or_equal_to" }

      it "returns an sql string representing greater than or equal to value" do
        filter = described_class.new(comparator, value)
        expect(filter.to_sql).to eq("submissions.pageview_count >= #{value}")
      end
    end

    context "when comparator is greater_than" do
      let(:comparator) { "greater_than" }

      it "returns an sql string representing greater than value" do
        filter = described_class.new(comparator, value)
        expect(filter.to_sql).to eq("submissions.pageview_count > #{value}")
      end
    end
  end
end
