# frozen_string_literal: true
require File.join(File.dirname(__FILE__), 'common')

class SituateCustomContentLinksWorker
  include Sidekiq::Worker
  include Common

  def perform(question_id)
    tagged_logger.info 'Started'

    tagged_logger.info "Question ID: #{question_id}"
    question = Question.find(question_id)

    parsed_custom_content = parse_html(question.custom_content)

    ActiveRecord::Base.transaction do
      active_custom_content_links = parsed_custom_content.css('a').map do |link|
        link['data-pi-link-id'] ||= SecureRandom.uuid # Embedding an identifier if empty

        custom_content_link = question.custom_content_links.find_or_initialize_by(link_identifier: link['data-pi-link-id'])
        custom_content_link.update!(link_text: link.content, link_url: link['href'])
        custom_content_link
      end
      tagged_logger.info "Active Links: #{active_custom_content_links.pluck(:id)}"

      custom_content_links_to_archive = CustomContentLink.active.where(question_id: question_id) - active_custom_content_links
      tagged_logger.info "Archived Links: #{custom_content_links_to_archive.pluck(:id)}"
      custom_content_links_to_archive.each(&:archive!)

      situated_custom_content = serialize_html(parsed_custom_content)
      tagged_logger.info "New Custom Content: #{situated_custom_content}"
      question.update!(custom_content: situated_custom_content)
    end
  rescue StandardError => e
    Rollbar.error e
    tagged_logger.error e
  ensure
    tagged_logger.info "Finished"
  end

  def parse_html(html)
    # Parsing with Nokogiri::HTML::DocumentFragment so that the reserved characters are untouched https://stackoverflow.com/a/2567911/12065544
    # Wrapping inside <div> to ensure there is always a single root node
    Nokogiri::HTML::DocumentFragment.parse("<div>#{html}</div>")
  end

  def serialize_html(dom)
    # Removing the <div> attached in parse_html
    dom.to_html.delete_prefix('<div>').delete_suffix('</div>')
  end
end
