# frozen_string_literal: true

require 'spec_helper'

describe SituateCustomContentLinksWorker do
  let(:link_url) { FFaker::Internet.http_url }
  let(:link_text) { FFaker::Lorem.word }
  let(:custom_content) { <<-HTML }
      <p><a href='#{link_url}'>#{link_text}</a></p>
  HTML

  let(:question) { create(:custom_content_question, custom_content: custom_content) }

  before do
    # This link record will be archived because its link doesn't exist in custom_content
    create(:custom_content_link, custom_content_question: question)

    described_class.new.perform(question.id)
  end

  it 'embeds identifiers in custom_content' do
    expect(question.reload.custom_content).to include('data-pi-link-id')
  end

  it 'trims the root div tag' do
    custom_content = question.reload.custom_content
    expect(custom_content).not_to start_with('<div>')
    expect(custom_content).not_to end_with('</div>')
  end

  it 'creates link records' do
    expect(question.custom_content_links.exists?(link_url: link_url, link_text: link_text)).to be true
  end

  it 'archives link records' do
    expect(CustomContentLink.where.not(archived_at: nil).exists?(custom_content_question: question)).to be true
  end

  context 'with existing links' do
    let(:custom_content_link) { question.custom_content_links.first }

    before do
      # Updating the URL & text to confirm the actual link in custom_content will be reflected on database
      custom_content_link.update(link_url: FFaker::Internet.http_url, link_text: FFaker::Lorem.word)

      described_class.new.perform(question.id)
    end

    it 'updates their url and text' do
      custom_content_link.reload
      expect(custom_content_link.link_url).to eq link_url
      expect(custom_content_link.link_text).to eq link_text
    end
  end
end
