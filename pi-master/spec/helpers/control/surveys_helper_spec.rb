# frozen_string_literal: true

require 'spec_helper'

describe Control::SurveysHelper do
  describe '#themes_for_survey' do
    let!(:account) { create(:account) }

    let!(:theme_css) { create(:theme, theme_type: :css, account: account) }
    let!(:theme_css2) { create(:theme, theme_type: :css, account: account) }
    let!(:theme_native) { create(:theme, theme_type: :native, account: account) }
    let!(:theme_native2) { create(:theme, theme_type: :native, account: account) }

    before do
      assign(:survey, create(:survey, account: account))
    end

    context 'when no account is found' do
      it 'returns the default theme' do
        assign(:survey, nil)
        expect(helper.themes_for_survey(:css)).to contain_exactly(['Default', nil])
      end
    end

    context 'when type is css' do
      it 'returns only css type themes' do
        ary = [['Default', nil], [theme_css.name, theme_css.id], [theme_css2.name, theme_css2.id]]
        expect(helper.themes_for_survey(:css)).to match_array(ary)
      end
    end

    context 'when type is native' do
      it 'returns only native type themes' do
        ary = [['Default', nil], [theme_native.name, theme_native.id], [theme_native2.name, theme_native2.id]]
        expect(helper.themes_for_survey(:native)).to match_array(ary)
      end
    end

    it "only returns themes that belong to the survey's account" do
      other_account = create(:account)
      other_theme = create(:theme, account: other_account)
      other_account2 = create(:account)
      other_theme2 = create(:theme, account: other_account2)

      themes = helper.themes_for_survey(:css)
      expect(themes).to include [theme_css.name, theme_css.id]
      expect(themes).to include [theme_css2.name, theme_css2.id]
      expect(themes).not_to include [other_theme.name, other_theme.id]
      expect(themes).not_to include [other_theme2.name, other_theme2.id]
    end
  end

  describe '#report_subnav_link' do
    let(:report_url) { '/report' }
    let(:page_event_url) { '/page_event' }

    before do
      allow(helper).to receive(:report_survey_path).and_return report_url
      allow(helper).to receive(:report_survey_path).with(nil, show_page_event: true).and_return page_event_url
    end

    context 'when a user is on reporting page and there are relevant page event data' do
      it 'returns both the report url and the page event url' do
        allow(helper).to receive_messages(on_reporting?: true, page_event_data_exist?: true)

        urls = helper.report_subnav_link[:popupLinks].pluck(:url)
        expect(urls).to contain_exactly(report_url, page_event_url)
      end
    end

    context "when a user isn't on reporting page but there are relevant page event data" do
      it 'only returns the report url' do
        allow(helper).to receive_messages(on_reporting?: false, page_event_data_exist?: true)

        url = helper.report_subnav_link[:url]
        expect(url).to eq report_url
      end
    end

    context "when a user is on reporting page but there aren't relevant page event data" do
      it 'only returns the report url' do
        allow(helper).to receive_messages(on_reporting?: true, page_event_data_exist?: false)

        url = helper.report_subnav_link[:url]
        expect(url).to eq report_url
      end
    end
  end
end
