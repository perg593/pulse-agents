# frozen_string_literal: true

# Shared examples for a rack endpoint that returns surveys according to geotargeting triggers
RSpec.shared_examples "rack geo targeting trigger" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }

  def make_call(account, geoip_headers)
    raise NotImplementedError, "You must implement 'make_call' to use 'rack geo targeting trigger'"
  end

  def it_should_return_survey(geoip_headers: {})
    json_response = make_call(account, geoip_headers)

    expect(json_response.dig("survey", "id").to_i).not_to eq(0)
  end

  def it_should_not_return_survey(geoip_headers: {})
    expect(make_call(account, geoip_headers)).to eq({})
  end

  describe 'geo targeting' do
    it 'does not return the survey if country is different' do
      survey.geoip_triggers.create(geo_country: 'Japan', geo_state_or_dma: '')
      expect(survey.reload.geoip_triggers.count).to eq(1)

      geoip_headers = { GEOIP_COUNTRY_NAME: "France" }

      it_should_not_return_survey(geoip_headers: geoip_headers)
    end

    it 'does not return the survey if country is US but state different' do
      survey.geoip_triggers.create(geo_country: 'United States', geo_state_or_dma: 'Alabama')
      expect(survey.reload.geoip_triggers.count).to eq(1)

      geoip_headers = { GEOIP_COUNTRY_NAME: 'United States', GEOIP_STATE_NAME: 'Alaska' }

      it_should_not_return_survey(geoip_headers: geoip_headers)
    end

    it 'does not return the survey if country is US but DMA different' do
      survey.geoip_triggers.create(geo_country: 'United States', geo_state_or_dma: '623')
      expect(survey.reload.geoip_triggers.count).to eq(1)

      geoip_headers = { GEOIP_COUNTRY_NAME: 'United States', GEOIP_DATA_METRO_CODE: '501' }

      it_should_not_return_survey(geoip_headers: geoip_headers)
    end

    it 'returns the survey if there is one trigger defined with only country (non-US)' do
      survey.geoip_triggers.create(geo_country: 'Japan', geo_state_or_dma: '')
      expect(survey.reload.geoip_triggers.count).to eq(1)

      geoip_headers = { GEOIP_COUNTRY_NAME: 'Japan' }

      it_should_return_survey(geoip_headers: geoip_headers)
    end

    it 'returns the survey if there are two triggers defined with only countries (non-US)' do
      survey.geoip_triggers.create(geo_country: 'Japan', geo_state_or_dma: '')
      survey.geoip_triggers.create(geo_country: 'France', geo_state_or_dma: '')
      expect(survey.reload.geoip_triggers.count).to eq(2)

      geoip_headers = { GEOIP_COUNTRY_NAME: 'Japan' }

      it_should_return_survey(geoip_headers: geoip_headers)
    end

    it 'returns the survey if there is one trigger with country and states (US)' do
      survey.geoip_triggers.create(geo_country: 'United States', geo_state_or_dma: 'Alabama')
      expect(survey.reload.geoip_triggers.count).to eq(1)

      geoip_headers = { GEOIP_COUNTRY_NAME: 'United States', GEOIP_STATE_NAME: 'Alabama' }

      it_should_return_survey(geoip_headers: geoip_headers)
    end

    it 'returns the survey if there is one trigger with only country (US)' do
      survey.geoip_triggers.create(geo_country: 'United States', geo_state_or_dma: '')
      expect(survey.reload.geoip_triggers.count).to eq(1)

      geoip_headers = { GEOIP_COUNTRY_NAME: 'United States', GEOIP_STATE_NAME: 'Alabama' }

      it_should_return_survey(geoip_headers: geoip_headers)
    end

    it 'returns the survey if DMA is the same' do
      survey.geoip_triggers.create(geo_country: 'United States', geo_state_or_dma: '623')
      expect(survey.reload.geoip_triggers.count).to eq(1)

      geoip_headers = { GEOIP_COUNTRY_NAME: 'United States', GEOIP_DATA_METRO_CODE: '623' }

      it_should_return_survey(geoip_headers: geoip_headers)
    end

    it 'returns the survey if multiple DMA and states' do
      survey.geoip_triggers.create(geo_country: 'United States', geo_state_or_dma: '623')
      survey.geoip_triggers.create(geo_country: 'United States', geo_state_or_dma: 'Texas')
      survey.geoip_triggers.create(geo_country: 'Japan')
      survey.geoip_triggers.create(geo_country: 'France')
      expect(survey.reload.geoip_triggers.count).to eq(4)

      geoip_headers = { GEOIP_COUNTRY_NAME: 'United States', GEOIP_DATA_METRO_CODE: '623', GEOIP_STATE_NAME: 'Texas' }

      it_should_return_survey(geoip_headers: geoip_headers)
    end

    it 'returns the survey if there are several mixed triggers (US and non-US)' do
      survey.geoip_triggers.create(geo_country: 'France', geo_state_or_dma: '')
      survey.geoip_triggers.create(geo_country: 'United States', geo_state_or_dma: 'Alabama')
      survey.geoip_triggers.create(geo_country: 'Japan', geo_state_or_dma: '')
      expect(survey.reload.geoip_triggers.count).to eq(3)

      geoip_headers = { GEOIP_COUNTRY_NAME: 'United States', GEOIP_STATE_NAME: 'Alabama' }

      it_should_return_survey(geoip_headers: geoip_headers)
    end
  end
end
