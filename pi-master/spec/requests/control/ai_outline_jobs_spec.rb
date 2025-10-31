# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/gamma_client/gamma_client'

describe 'Control::AIOutlineJobsController' do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:survey) { create(:survey, account: account) }
  let(:outline_content) { "Sample outline content for Gamma presentation" }
  let(:ai_outline_job) { create(:ai_outline_job, survey: survey, status: :outline_completed, outline_content: outline_content) }

  before do
    sign_in user
  end

  describe 'POST /surveys/:survey_id/ai_outline_jobs/generate_gamma_presentation' do
    context 'when user has permission' do
      before do
        allow(GammaClient).to receive(:generate_gamma).and_return('gen_123456')
      end

      it 'starts Gamma presentation generation successfully' do
        post "/surveys/#{survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          job_id: ai_outline_job.id,
          outline_content: outline_content
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['generation_id']).to eq('gen_123456')
        expect(json_response['message']).to eq('Gamma presentation generation started')
      end

      it 'updates the job with the outline content used for Gamma generation' do
        modified_outline = "Modified outline content for Gamma generation"

        post "/surveys/#{survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          job_id: ai_outline_job.id,
          outline_content: modified_outline
        }

        expect(response).to have_http_status(:ok)

        # Reload the job to get updated attributes
        ai_outline_job.reload
        expect(ai_outline_job.outline_content).to eq(modified_outline)
        expect(ai_outline_job.gamma_generation_id).to eq('gen_123456')
        expect(ai_outline_job.status).to eq('generating_gamma')
      end

      it 'calls GammaClient with correct parameters' do
        allow(GammaClient).to receive(:generate_gamma).with(
          input_text: outline_content
        ).and_return('gen_123456')

        post "/surveys/#{survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          job_id: ai_outline_job.id,
          outline_content: outline_content
        }
      end
    end

    context 'when job ID is missing' do
      it 'returns an error' do
        post "/surveys/#{survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          outline_content: outline_content
        }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Job ID is required')
      end
    end

    context 'when user does not have permission' do
      let(:other_survey) { create(:survey) }

      it 'redirects unauthorized users' do
        other_job = create(:ai_outline_job, survey: other_survey, status: :outline_completed, outline_content: outline_content)
        post "/surveys/#{other_survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          job_id: other_job.id,
          outline_content: outline_content
        }

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(dashboard_path)
      end
    end

    context 'when Gamma API fails' do
      before do
        allow(GammaClient).to receive(:generate_gamma).and_raise(
          GammaClient::HTTP::GammaError.new('API key invalid', 401)
        )
      end

      it 'returns an error response' do
        post "/surveys/#{survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          job_id: ai_outline_job.id,
          outline_content: outline_content
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Gamma generation failed')
      end
    end

    context 'when Gamma generation fails to start or returns no generation ID' do
      before do
        allow(GammaClient).to receive(:generate_gamma).and_return(nil)
      end

      it 'returns an error response' do
        post "/surveys/#{survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          job_id: ai_outline_job.id,
          outline_content: outline_content
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to start Gamma generation')
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(GammaClient).to receive(:generate_gamma).and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns an internal server error' do
        post "/surveys/#{survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          job_id: ai_outline_job.id,
          outline_content: outline_content
        }

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('An unexpected error occurred while generating the presentation')
      end
    end

    context 'when in development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'returns a mock generation ID without calling GammaClient' do
        expect(GammaClient).not_to receive(:generate_gamma)

        post "/surveys/#{survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          job_id: ai_outline_job.id,
          outline_content: outline_content
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['generation_id']).to start_with('dev_mock_')
        expect(json_response['message']).to eq('Gamma presentation generation started')
      end

      it 'updates the job with outline content in development mode' do
        modified_outline = "Development mode modified outline"

        post "/surveys/#{survey.id}/ai_outline_jobs/generate_gamma_presentation", params: {
          job_id: ai_outline_job.id,
          outline_content: modified_outline
        }

        expect(response).to have_http_status(:ok)

        # Reload the job to get updated attributes
        ai_outline_job.reload
        expect(ai_outline_job.outline_content).to eq(modified_outline)
        expect(ai_outline_job.gamma_generation_id).to start_with('dev_mock_')
        expect(ai_outline_job.status).to eq('generating_gamma')
      end
    end
  end

  describe 'GET /surveys/:survey_id/ai_outline_jobs/check_gamma_presentation_status' do
    let(:generation_id) { 'gen_123456' }
    let(:gamma_job) { create(:ai_outline_job, survey: survey, status: :generating_gamma, gamma_generation_id: generation_id) }

    context 'when user has permission' do
      before do
        allow(GammaClient).to receive(:get_generation_status).and_return({
                                                                           'generationId' => generation_id,
          'status' => 'completed',
          'gammaUrl' => 'https://gamma.app/docs/abc123'
                                                                         })
      end

      it 'returns the generation status' do
        gamma_job # Create the job
        gamma_job # Create the job
        get "/surveys/#{survey.id}/ai_outline_jobs/check_gamma_presentation_status", params: {
          generation_id: generation_id
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['status']).to eq('completed')
        expect(json_response['gamma_url']).to eq('https://gamma.app/docs/abc123')
        expect(json_response['generation_id']).to eq(generation_id)
      end

      it 'calls GammaClient with correct parameters' do
        gamma_job # Create the job
        expect(GammaClient).to receive(:get_generation_status).with(generation_id)

        gamma_job # Create the job
        get "/surveys/#{survey.id}/ai_outline_jobs/check_gamma_presentation_status", params: {
          generation_id: generation_id
        }
      end
    end

    context 'when generation_id is missing' do
      it 'returns a bad request error' do
        get "/surveys/#{survey.id}/ai_outline_jobs/check_gamma_presentation_status"

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Generation ID is required')
      end
    end

    context 'when GammaClient returns nil' do
      before do
        allow(GammaClient).to receive(:get_generation_status).and_return(nil)
      end

      it 'returns an error response' do
        gamma_job # Create the job
        get "/surveys/#{survey.id}/ai_outline_jobs/check_gamma_presentation_status", params: {
          generation_id: generation_id
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to check Gamma presentation status')
      end
    end

    context 'when GammaClient raises an error' do
      before do
        allow(GammaClient).to receive(:get_generation_status).and_raise(GammaClient::HTTP::GammaError.new('API Error', 500))
      end

      it 'returns an error response' do
        gamma_job # Create the job
        get "/surveys/#{survey.id}/ai_outline_jobs/check_gamma_presentation_status", params: {
          generation_id: generation_id
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to check status: API Error')
      end
    end

    context 'when in development environment with mock generation ID' do
      let(:mock_generation_id) { 'dev_mock_abc123' }
      let(:mock_job) { create(:ai_outline_job, survey: survey, status: :generating_gamma, gamma_generation_id: mock_generation_id) }

      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'returns mock completed status without calling GammaClient' do
        mock_job # Create the job
        expect(GammaClient).not_to receive(:get_generation_status)

        get "/surveys/#{survey.id}/ai_outline_jobs/check_gamma_presentation_status", params: {
          generation_id: mock_generation_id
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['status']).to eq('completed')
        expect(json_response['gamma_url']).to eq('https://gamma.app/docs/dev-mock-presentation')
        expect(json_response['generation_id']).to eq(mock_generation_id)
      end
    end
  end

  describe 'POST /surveys/:survey_id/ai_outline_jobs/download_gamma_presentation' do
    let(:gamma_url) { 'https://gamma.app/docs/abc123' }

    context 'when user has permission' do
      it 'returns the download URL' do
        post "/surveys/#{survey.id}/ai_outline_jobs/download_gamma_presentation", params: {
          gamma_url: gamma_url
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['download_url']).to eq(gamma_url)
        expect(json_response['message']).to eq('Please visit the URL to download your presentation')
      end
    end

    context 'when gamma_url is missing' do
      it 'returns an error' do
        post "/surveys/#{survey.id}/ai_outline_jobs/download_gamma_presentation"

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Gamma URL is required')
      end
    end

    context 'when gamma_url is blank' do
      it 'returns an error' do
        post "/surveys/#{survey.id}/ai_outline_jobs/download_gamma_presentation", params: {
          gamma_url: ''
        }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Gamma URL is required')
      end
    end

    context 'when user does not have permission' do
      let(:other_survey) { create(:survey) }

      it 'redirects unauthorized users' do
        post "/surveys/#{other_survey.id}/ai_outline_jobs/download_gamma_presentation", params: {
          gamma_url: gamma_url
        }

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
