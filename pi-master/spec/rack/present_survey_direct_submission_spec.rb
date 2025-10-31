# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "direct_submission_schema")

describe Rack::PresentSurvey do
  before do
    Sidekiq::Queue.new.clear
    Account.delete_all
    Survey.delete_all
    Trigger.delete_all
    Question.delete_all
    PossibleAnswer.delete_all
    Device.delete_all
    Submission.delete_all
    Answer.delete_all
    DeviceData.delete_all

    @account = create(:account)
    @survey = create(:survey)
    @survey.account = @account
    @survey.save
    @survey.reload
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:callback) { 'window.PulseInsightsObject.jsonpCallbacks.request_1' }

  it_behaves_like "account verifier" do
    def make_call(identifier_param)
      survey = create(:survey, account: create(:account))

      question_id = survey.questions.first.id
      answer_id = survey.questions.first.possible_answers.first.id

      url = "/q/#{question_id}/a/#{answer_id}?#{identifier_param}"

      rack_app(url)
    end
  end

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      survey = create(:survey, account: create(:account))

      question_id = survey.questions.first.id
      answer_id = survey.questions.first.possible_answers.first.id

      url = "/q/#{question_id}/a/#{answer_id}?identifier=#{account.identifier}"

      rack_app(url)
    end
  end

  it_behaves_like "rack parameter verifier", [:identifier], "/q/1/a/1"

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      survey = create(:survey, account: account)
      question_id = survey.questions.first.id
      answer_id = survey.questions.first.possible_answers.first.id

      headers = { X_REAL_IP: "192.168.0.1" }

      query = {
        identifier: account.identifier,
        callback: callback,
        preview_mode: preview_mode
      }.to_query

      url = "/q/#{question_id}/a/#{answer_id}?#{query}"

      rack_app(url, headers)
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"
      assert_valid_schema RackSchemas::DirectSubmission::SuccessfulResponseSchema, response.body
    end
  end

  describe '/q/:question_id/a/:answer_id' do
    describe 'params validation' do
      it "returns a 404 error if the question_id is invalid" do
        question_id = @survey.questions.first.id
        answer_id = @survey.questions.first.possible_answers.first.id

        expect(rack_app("/q/#{question_id}/a/#{answer_id}?identifier=#{@account.identifier}").code).to eq('200')
        expect(rack_app("/q/999/a/#{answer_id}?identifier=#{@account.identifier}").code).to eq('404')
      end

      it "requires a text answer if the question is a free text question" do
        create(:free_text_question, survey: @survey)

        question_id = @survey.reload.questions.last.id

        response = rack_app("/q/#{question_id}?identifier=#{@account.identifier}&text=I%20don%27t%20know")

        expect(response.code).to eq('200')
        expect(rack_app("/q/#{question_id}?identifier=#{@account.identifier}").code).to eq('400')
      end
    end

    it 'enqueues DirectSubmissionWorker' do
      question_id = @survey.questions.first.id
      answer_id = @survey.questions.first.possible_answers.first.id

      rack_app("/q/#{question_id}/a/#{answer_id}?identifier=#{@account.identifier}")

      expect(Sidekiq::Queue.new.size).to eq(1)
      expect(Sidekiq::Queue.new.first['class']).to eq('DirectSubmissionWorker')

      worker_arguments = Sidekiq::Queue.new.first['args']

      expect(worker_arguments[0]).to eq @account.identifier
      expect(worker_arguments[1]).not_to be_nil # udid. Cannot retrieve from here
      expect(worker_arguments[2]).to eq @survey.id.to_s # TODO: Be consistent about string vs. integer values
      expect(worker_arguments[3]).to eq ""
      expect(worker_arguments[4]).to be_nil
      expect(worker_arguments[5]).to eq "Ruby"
      expect(worker_arguments[6]).to eq "{}"
      expect(worker_arguments[7]).to eq question_id
      expect(worker_arguments[8]).to eq answer_id
      # TODO: Check worker_arguments[9], i.e. the free text answer
    end

    describe 'redirect validation' do
      let(:question) { @survey.questions.first }
      let(:possible_answer) { question.possible_answers.first }

      let(:allowed_domain) { "test.com" }

      before do
        @account.update(domains_to_allow_for_redirection: [allowed_domain])
      end

      context 'with no redirection specified' do
        it "returns 200" do
          response = rack_app("/q/#{question.id}/a/#{possible_answer.id}?identifier=#{@account.identifier}")
          expect(response.code).to eq('200')
          expect(response.body).to eq('Thank you!')

          assert_valid_schema RackSchemas::DirectSubmission::SuccessfulResponseSchema, response.body
        end
      end

      context 'when a domain is allowed' do
        let(:allowed_url) { "https://subdomain.#{allowed_domain}/some_path" }

        context 'with "redirect" parameter' do
          it 'redirects a request' do
            response = rack_app("/q/#{question.id}/a/#{possible_answer.id}?identifier=#{@account.identifier}&redirect=#{allowed_url}")
            expect(response.code).to eq '302'
            expect(response['Location']).to eq allowed_url
          end
        end

        context 'with "referer" header' do
          it 'redirects a request' do
            response = rack_app("/q/#{question.id}/a/#{possible_answer.id}?identifier=#{@account.identifier}", { 'REFERER' => allowed_url })
            expect(response.code).to eq '302'
            expect(response['Location']).to eq allowed_url
          end
        end

        context 'with "url" header' do
          it 'redirects a request' do
            response = rack_app("/q/#{question.id}/a/#{possible_answer.id}?identifier=#{@account.identifier}&url=#{allowed_url}")
            expect(response.code).to eq '302'
            expect(response['Location']).to eq allowed_url
          end
        end
      end

      context "when a domain isn't allowed" do
        let(:unallowed_url) { 'https://bad.com/malicious.js' }

        context 'with "redirect" parameter' do
          it 'returns an error' do
            response = rack_app("/q/#{question.id}/a/#{possible_answer.id}?identifier=#{@account.identifier}&redirect=#{unallowed_url}")
            expect(response.code).to eq '400'
            expect(response.body).to eq '"redirect" parameter not valid'
          end
        end

        context 'with "referer" header' do
          it 'returns an error' do
            response = rack_app("/q/#{question.id}/a/#{possible_answer.id}?identifier=#{@account.identifier}", { 'REFERER' => unallowed_url })
            expect(response.code).to eq '400'
            expect(response.body).to eq '"redirect" parameter not valid'
          end
        end

        context 'with "url" header' do
          it 'returns an error' do
            response = rack_app("/q/#{question.id}/a/#{possible_answer.id}?identifier=#{@account.identifier}&url=#{unallowed_url}")
            expect(response.code).to eq '400'
            expect(response.body).to eq '"redirect" parameter not valid'
          end
        end
      end
    end

    describe 'non-existing surveys' do
      it 'returns a 404' do
        expect(rack_app("/q/123/a/456?identifier=#{@account.identifier}&a=1&b=2").code).to eq('404')
      end
    end

    # No effect on direct submission
    describe "frequency_caps" do
      subject { Sidekiq::Queue.new.size }

      let(:account) { create(:account, frequency_cap_enabled: true, frequency_cap_type: 'hours', frequency_cap_limit: 1, frequency_cap_duration: 2) }
      let(:survey) { create(:survey, account: account) }
      let(:question_id) { survey.questions.first.id }
      let(:answer_id) { survey.questions.first.possible_answers.sort_by_position.first.id }
      let(:base_url) do
        "/q/#{question_id}/a/#{answer_id}?identifier=#{account.identifier}"
      end
      let(:extra_parameters) { "" }

      before do
        device = create(:device, udid: udid)
        submission = create(:submission, device_id: device.id, survey_id: survey.id, created_at: 30.minutes.ago)

        @response = rack_app("#{base_url}#{extra_parameters}")
      end

      context "when preview_mode is true" do
        let(:extra_parameters) { "&preview_mode=true" }

        it { is_expected.to eq 1 }
      end

      context "when preview_mode is not provided" do
        it { is_expected.to eq 1 }
      end
    end

    describe 'non-live surveys' do
      context "when draft survey" do
        let(:account) { survey.account }
        let(:survey) { create(:survey, account: create(:account), status: :draft) }
        let(:question_id) { survey.questions.first.id }
        let(:answer_id) { survey.questions.first.possible_answers.sort_by_position.first.id }
        let(:base_url) do
          "/q/#{question_id}/a/#{answer_id}?identifier=#{account.identifier}"
        end
        let(:extra_parameters) { "" }

        before do
          @response = rack_app("#{base_url}#{extra_parameters}")
        end

        it "redirects" do
          expect(@response.code).to eq('200')
          expect(@response.body).to eq('Thank you!')
          expect(Sidekiq::Queue.new.size).to eq(0)
        end

        context "when preview_mode is true" do
          let(:extra_parameters) { "&preview_mode=true" }

          it "succeeds" do
            expect(Sidekiq::Queue.new.size).to eq(1)
            expect(Sidekiq::Queue.new.first['class']).to eq('DirectSubmissionWorker')
          end
        end
      end

      it 'redirects paused survey' do
        @survey.status = :paused
        @survey.save
        @survey.reload

        question_id = @survey.questions.first.id
        answer_id = @survey.questions.first.possible_answers.first.id

        response = rack_app("/q/#{question_id}/a/#{answer_id}?identifier=#{@account.identifier}")
        expect(response.code).to eq('200')
        expect(response.body).to eq('Thank you!')
        expect(Sidekiq::Queue.new.size).to eq(0)
      end

      it 'redirects complete survey' do
        @survey.status = :complete
        @survey.save
        @survey.reload

        question_id = @survey.questions.first.id
        answer_id = @survey.questions.first.possible_answers.first.id

        response = rack_app("/q/#{question_id}/a/#{answer_id}?identifier=#{@account.identifier}")
        expect(response.code).to eq('200')
        expect(response.body).to eq('Thank you!')
        expect(Sidekiq::Queue.new.size).to eq(0)
      end

      it 'redirects archived survey' do
        @survey.status = :archived
        @survey.save
        @survey.reload

        question_id = @survey.questions.first.id
        answer_id = @survey.questions.first.possible_answers.first.id

        response = rack_app("/q/#{question_id}/a/#{answer_id}?identifier=#{@account.identifier}")
        expect(response.code).to eq('200')
        expect(response.body).to eq('Thank you!')
        expect(Sidekiq::Queue.new.size).to eq(0)
      end
    end

    describe 'custom data' do
      it "takes any extra parameter as custom data" do
        question_id = @survey.questions.first.id
        answer_id = @survey.questions.first.possible_answers.first.id

        expect(rack_app("/q/#{question_id}/a/#{answer_id}?identifier=#{@account.identifier}&a=1&b=2").code).to eq('200')

        custom_data = JSON.parse(Sidekiq::Queue.new.first.item['args'][6])

        expect(custom_data).to eq("a" => "1", "b" => "2")
      end
    end

    context "when enabled is false" do
      before do
        @account.update(enabled: false)

        question_id = @survey.questions.first.id
        answer_id = @survey.questions.first.possible_answers.first.id

        @response = rack_app("/q/#{question_id}/a/#{answer_id}?identifier=#{@account.identifier}")
      end

      it "does not enqueue a worker" do
        expect(Sidekiq::Queue.new.size).to eq(0)
      end

      it "does not redirect" do
        expect(@response.code).to eq('200')
        expect(@response.body).to include 'This account has been deactivated by the administrator.'
      end
    end

    describe 'bot' do
      it 'returns a 403' do
        question_id = @survey.questions.first.id
        answer_id = @survey.questions.first.possible_answers.first.id

        response = rack_app("/q/#{question_id}/a/#{answer_id}?identifier=#{@account.identifier}", 'User-Agent' => 'BLEXBot/1.0')

        expect(response.code).to eq('403')
      end

      it 'does not enqueue a worker' do
        question_id = @survey.questions.first.id
        answer_id = @survey.questions.first.possible_answers.first.id

        rack_app("/q/#{question_id}/a/#{answer_id}?identifier=#{@account.identifier}", 'User-Agent' => 'BLEXBot/1.0')

        expect(Sidekiq::Queue.new.size).to eq(0)
      end
    end
  end
end
