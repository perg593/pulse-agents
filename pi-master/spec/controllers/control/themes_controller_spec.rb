# frozen_string_literal: true
require 'spec_helper'

describe Control::ThemesController do
  describe 'deny_unauthorized_user' do
    # Using :subject because :expect doesn't accept a block when the matcher is :redirect_to
    subject { post :update, params: { id: @theme.id } }

    before do
      account = create(:account)
      user = create(:user, account: account)
      sign_in user

      different_account = create(:account)
      user.accounts << different_account
      @theme = create(:theme, account: different_account)
    end

    it { is_expected.to redirect_to themes_url }
  end

  describe "Theme requirement" do
    it "redirects to the survey dashboard when the theme is not found" do
      sign_in create(:user)

      endpoints = [
        { verb: :delete, url: :destroy },
        { verb: :get, url: :edit },
        { verb: :get, url: :show },
        { verb: :patch, url: :update }
      ]

      endpoints.each do |endpoint|
        it_handles_missing_records(endpoint)
      end
    end
  end

  describe 'GET #index' do
    it 'only shows themes that belong to the current account' do
      account = create(:account)
      user = create(:user, account: account)
      theme = create(:theme, account: account)

      other_account = create(:account)
      other_theme = create(:theme, account: other_account)

      sign_in user
      get :index

      themes = controller.instance_variable_get('@themes')
      expect(themes).to include theme
      expect(themes).not_to include other_theme
    end
  end

  describe 'POST #create' do
    let(:user) { create(:user) }

    context 'when the type is native' do
      context 'when json is valid' do
        it 'creates a native theme' do
          sign_in user
          post :create, params: { theme: { name: 'theme', theme_type: 'native', native_content: '{ "theme": "native" }' } }

          theme = Theme.last
          expect(theme.native?).to be true
          expect(theme.native_content).to eq("theme" => "native")
        end
      end

      context 'when json is invalid' do
        it 'does not create a native theme' do
          sign_in user

          params = { theme: { name: 'theme', theme_type: 'native', native_content: '{ theme: native }' } }
          expect { post :create, params: params }.not_to change { Theme.count }
        end
      end
    end
  end

  describe 'PATCH #update' do
    let!(:account) { create(:account) }
    let!(:user) { create(:user, account_id: account.id) }

    context 'when the type is native' do
      context 'when json is valid' do
        it 'updates a native theme' do
          sign_in user
          theme = create(:theme, theme_type: :native, native_content: { 'this' => 'valid' }, account: account)
          post :update, params: { id: theme.id, theme: { native_content: '{ "this": "still valid" }' } }

          expect(theme.reload.native?).to be true
          expect(theme.native_content).to eq("this" => "still valid")
        end
      end

      context 'when json is invalid' do
        it 'does not update a native theme' do
          sign_in user
          theme = create(:theme, theme_type: :native, native_content: { 'this' => 'valid' }, account: account)
          post :update, params: { id: theme.id, theme: { native_content: '{ this: invalid }' } }

          expect(theme.reload.native?).to be true
          expect(theme.native_content).to eq("this" => "valid")
        end
      end
    end
  end
end
