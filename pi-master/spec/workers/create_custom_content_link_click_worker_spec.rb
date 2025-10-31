# frozen_string_literal: true

require 'spec_helper'

describe CreateCustomContentLinkClickWorker do
  # TODO: Remove this "before" block after resolving https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2049
  before do
    Submission.delete_all
    Question.delete_all
    CustomContentLinkClick.delete_all
  end

  let(:survey) { create(:survey) }
  let(:custom_content_question) { create(:custom_content_question, survey: survey) }

  let(:link_text) { FFaker::Lorem.sentence }
  let(:link_url) { FFaker::Internet.http_url } # FFaker doesn't have "https_url"
  let(:link_identifier) { SecureRandom.uuid }
  let!(:custom_content_link) do
    create(:custom_content_link, custom_content_question: custom_content_question,
           link_text: link_text, link_url: link_url, link_identifier: link_identifier)
  end

  let(:submission) { create(:submission, survey: survey) }
  let(:client_key) { 'client_key' }
  let(:custom_data) { { custom: 1, data: 2 }.to_json }

  it { is_expected.to be_retryable true }

  it 'creates a CustomContentLinkClick record' do
    expect_custom_content_link_click_generated

    custom_content_link_click = CustomContentLinkClick.first
    expect(custom_content_link_click.submission).to eq submission
    expect(custom_content_link_click.custom_content_link).to eq custom_content_link
    expect(custom_content_link_click.client_key).to eq client_key
    expect(custom_content_link_click.custom_data).to eq custom_data
  end

  context 'when a question does not belong to the survey' do
    before do
      custom_content_question.update(survey: create(:survey))
    end

    it 'does not create a CustomContentLinkClick record' do
      expect_custom_content_link_click_not_generated
    end
  end

  context 'when a CustomContentLink does not belong to the question' do
    before do
      custom_content_link.update(custom_content_question: create(:custom_content_question))
    end

    it 'does not create a CustomContentLinkClick record' do
      expect_custom_content_link_click_not_generated
    end
  end

  context 'when link identifiers do not match' do
    before do
      custom_content_link.update(link_identifier: SecureRandom.uuid)
    end

    it 'does not create a CustomContentLinkClick record' do
      expect_custom_content_link_click_not_generated
    end
  end

  def expect_custom_content_link_click_generated
    expect { described_class.new.perform(submission.udid, custom_content_question.id, link_identifier, client_key, custom_data) }.
      to change { CustomContentLinkClick.count }.from(0).to(1)
  end

  def expect_custom_content_link_click_not_generated
    expect { described_class.new.perform(submission.udid, custom_content_question.id, link_identifier, client_key, custom_data) }.
      not_to change { CustomContentLinkClick.count }
  end
end
