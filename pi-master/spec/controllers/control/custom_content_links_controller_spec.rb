# frozen_string_literal: true

require 'spec_helper'

describe Control::CustomContentLinksController do
  describe "PATCH #update_color" do
    let(:custom_content_question) { create(:custom_content_question) }
    let(:custom_content_link) { create(:custom_content_link, custom_content_question: custom_content_question) }

    context 'when a user is not signed in' do
      subject { patch :update_color, params: { id: custom_content_link.id, question_id: custom_content_question.id } }

      it { is_expected.to redirect_to sign_in_path }
    end

    context 'when a user is a reporting user' do
      subject { patch :update_color, params: { id: custom_content_link.id, question_id: custom_content_question.id } }

      before do
        sign_in create(:reporting_only_user)
      end

      it { is_expected.to redirect_to dashboard_path }
    end

    context "when a question doesn't belong to the account" do
      before do
        sign_in create(:user)
      end

      it 'returns 404' do
        patch :update_color, params: { id: custom_content_link.id, question_id: custom_content_question.id }
        expect(response).to have_http_status :not_found
      end
    end

    context "when a link doesn't belong to the question" do
      before do
        user = create(:user)
        sign_in user
        custom_content_question.survey.update(account: user.account)
        custom_content_link.update(custom_content_question: create(:custom_content_question))
      end

      it 'returns 404' do
        patch :update_color, params: { id: custom_content_link.id, question_id: custom_content_question.id }
        expect(response).to have_http_status :not_found
      end
    end

    context 'when a color is blank' do
      before do
        user = create(:user)
        sign_in user
        custom_content_question.survey.update(account: user.account)
      end

      it 'returns 400' do
        patch :update_color, params: { id: custom_content_link.id, question_id: custom_content_question.id, color: nil }
        expect(response).to have_http_status :bad_request
      end
    end

    context 'when a color is invalid' do
      before do
        user = create(:user)
        sign_in user
        custom_content_question.survey.update(account: user.account)
      end

      it 'returns 400' do
        patch :update_color, params: { id: custom_content_link.id, question_id: custom_content_question.id, color: 'invalid' }
        expect(response).to have_http_status :bad_request
      end
    end

    it 'updates a color' do
      user = create(:user)
      sign_in user
      custom_content_question.survey.update(account: user.account)
      color = '#000000'

      expect(custom_content_link.reload.report_color).not_to eq color
      patch :update_color, params: { id: custom_content_link.id, question_id: custom_content_question.id, color: color }
      expect(response).to have_http_status :ok
      expect(custom_content_link.reload.report_color).to eq color
    end
  end
end
