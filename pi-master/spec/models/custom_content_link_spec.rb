# frozen_string_literal: true
require 'spec_helper'

RSpec.describe CustomContentLink do
  let(:custom_content_link) { create(:custom_content_link) }

  it_behaves_like 'color validation' do
    subject { custom_content_link }

    let(:attribute_to_validate) { :report_color }
  end

  it_behaves_like 'filter sharing' do
    def it_filters(filters)
      expect(custom_content_link.click_count(filters: filters)).
        to eq CustomContentLinkClick.filtered_clicks(custom_content_link.clicks, filters: filters).count
    end

    def make_records(filter_attribute = nil, attribute_value = nil)
      make_click and return if filter_attribute.nil?

      case filter_attribute
      when :created_at
        make_click(click_extras: { created_at: attribute_value })
      when :device_type, :url, :pageview_count, :visit_count
        make_click(submission_extras: { visit_count: attribute_value })
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
