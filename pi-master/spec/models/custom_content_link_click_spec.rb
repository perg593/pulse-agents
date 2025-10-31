# frozen_string_literal: true
require 'spec_helper'

RSpec.describe CustomContentLinkClick do
  describe 'filtered_clicks' do
    let(:custom_content_link) { create(:custom_content_link, custom_content_question: create(:custom_content_question)) }

    it_behaves_like "filter sharing" do
      def it_filters(filters)
        scope = described_class.all

        filters.each do |filter_key, filter_value|
          scope =
            case filter_key
            when :date_range
              scope.where(created_at: filter_value)
            when :device_types
              scope.joins(:submission).where(submissions: { device_type: filter_value })
            when :completion_urls
              scope.joins(:submission).where(CompletionUrlFilter.combined_sql(filter_value))
            when nil, :possible_answer_id
              scope
            when :pageview_count, :visit_count
              scope.joins(:submission).where(filter_value.to_sql)
            else
              raise "Unrecognized filter #{filter_key}"
            end
        end

        expect(described_class.filtered_clicks(described_class.all, filters: filters).count).to eq scope.count
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        make_click and return if filter_attribute.nil?

        case filter_attribute
        when :created_at
          make_click(click_extras: { created_at: attribute_value })
        when :device_type, :url, :pageview_count, :visit_count
          make_click(submission_extras: { filter_attribute => attribute_value })
        when :possible_answer_id
          # unsupported
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end

      def make_click(submission_extras: {}, click_extras: {})
        submission = create(:submission, **submission_extras)
        create(:custom_content_link_click, custom_content_link: custom_content_link, submission: submission, **click_extras)
      end
    end
  end
end
