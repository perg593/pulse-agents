# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')
include RackAppSpecHelper

require File.join(File.dirname(__FILE__), "schemas", "serve_email_schema")

describe Rack::Serve do
  before do
    Account.delete_all
    Survey.delete_all
    Question.delete_all
    Device.delete_all
    DeviceData.delete_all
    Trigger.delete_all
    Answer.delete_all
    AnswerImage.delete_all
    Sidekiq::Queue.new.clear
  end

  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:udid2) { '00000000-0000-4000-f000-000000000002' }
  let(:client_key) { 'my_awesome_client_key' }

  let(:required_headers) do
    {
      'Referer' => 'http://localhost:3000',
      "AMP_EMAIL_SENDER" => "hello@pulseinsights.com"
    }
  end

  it_behaves_like "account verifier" do
    def make_call(identifier_param)
      required_headers = { Referer: "http://localhost:3000" }

      url = "/serve?device_type=email&client_key=#{client_key}#{identifier_param}"

      rack_app(url, required_headers)
    end
  end

  it_behaves_like "disabled account verifier" do
    def make_call(account)
      create(:survey, account: account, email_enabled: true)

      url = "/serve?device_type=email&client_key=#{client_key}&identifier=#{account.identifier}"

      rack_app(url, required_headers)
    end
  end

  it_behaves_like "accounts.ips_to_block-based request blocker" do
    def make_call(preview_mode)
      survey = create(:survey, account: account, email_enabled: true)

      headers = { X_REAL_IP: "192.168.0.1" }

      query = {
        device_type: "email",
        identifier: survey.account.identifier,
        client_key: client_key,
        preview_mode: preview_mode
      }.to_query

      url = "/serve?#{query}"

      rack_app(url, required_headers.merge(headers))
    end

    def non_blocked_response(response)
      expect(response.code).to eq "200"
      assert_valid_schema RackSchemas::ServeEmail::SuccessfulResponseSchema, parse_json_response(response.body)
    end
  end

  it_behaves_like "rack parameter verifier", [:identifier, :device_type, :client_key], "/serve" do
    let(:optional_defaults) { { device_type: "email" } }
  end

  describe "response validation" do
    let(:account) { create(:account) }

    before do
      survey = create(:survey, account: account, email_enabled: true)

      Question.question_types.keys.map(&:to_sym).each do |question_type|
        create(question_type, survey: survey)
      end

      @response = rack_app(url, required_headers)
    end

    context "when successful" do
      let(:url) { "/serve?device_type=email&client_key=#{client_key}&identifier=#{account.identifier}" }

      it "returns code 200" do
        expect(@response.code).to eq "200"
      end

      it "returns the expected schema" do
        json_response = parse_json_response(@response.body)
        assert_valid_schema RackSchemas::ServeEmail::SuccessfulResponseSchema, json_response
      end
    end

    context "when unsuccessful" do
      let(:url) { "/serve?device_type=email&client_key=#{client_key}" }

      it "returns code 400" do
        expect(@response.code).to eq "400"
      end

      it "returns the expected schema" do
        assert_valid_schema RackSchemas::ServeEmail::ErrorResponseSchema, @response.body
      end
    end
  end

  describe '/serve?device_type=email' do
    before do
      @account = create(:account)
    end

    it "returns a response of type application/javascript" do
      response = rack_app(serve_url, required_headers)

      expect(response['Content-Type']).to eq('application/javascript')
    end

    it "returns failure when no account identifier is provided" do
      response = rack_app("/serve?device_type=email&client_key=#{client_key}", required_headers)

      expect(response.code).to eq("400")
    end

    it "returns failure when no client key is provided" do
      response = rack_app("/serve?device_type=email&identifier=#{@account.identifier}", required_headers)

      expect(response.code).to eq("400")
    end

    it "returns failure when no CORS headers are provided" do
      response = rack_app(serve_url)
      expect(response.code).to eq("400")

      json_response = parse_json_response(response.body)
      expect(json_response).to eq(["Invalid CORS headers"])
    end

    it "returns failure when invalid CORS headers are provided" do
      response = rack_app(serve_url, "AMP_EMAIL_SENDER" => "invalid@malicious.ca")
      expect(response.code).to eq("400")

      json_response = parse_json_response(response.body)
      expect(json_response).to eq(["invalid@malicious.ca not found in list of approved senders"])
    end

    it "returns something appropriate when no surveys are found" do
      it_should_not_return_survey

      json_response = rack_app_as_json("#{serve_url}&survey_id=123", required_headers)

      assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
    end

    it "returns survey attributes and submission id" do
      setting = @account.personal_data_setting
      survey = create(:survey, account: @account, email_enabled: true)

      response_payload = rack_app_as_json(serve_url, required_headers)

      survey_object = response_payload["survey"]

      expect(survey_object["id"]).to eq(survey.id.to_s)
      expect(survey_object["thank_you_message"]).to eq(survey.thank_you)
      expect(survey_object["personal_data_masking_enabled"]).to eq(setting.masking_enabled)
      expect(survey_object["phone_number_masked"]).to eq(setting.phone_number_masked)
      expect(survey_object["email_masked"]).to eq(setting.email_masked)
    end

    it "returns the specified survey" do
      survey = create(:survey, account: @account, email_enabled: true)

      response_payload = rack_app_as_json("#{serve_url}&survey_id#{survey.id}", required_headers)

      expect(response_payload["survey"]["id"]).to eq(survey.id.to_s)
    end

    it "returns survey invitation attributes" do
      survey = create(:survey_with_one_question, account: @account, email_enabled: true)
      survey.reload

      response_payload = rack_app_as_json(serve_url, required_headers)

      invitation_object = response_payload["survey"]["invitation"]

      expect(invitation_object["label_text"]).to eq(survey.invitation)
      expect(invitation_object["button_text"]).to eq(survey.invitation_button)
      expect(invitation_object["button_present"]).to eq(!survey.invitation_button_disabled)
      expect(invitation_object["first_question_id"]).to eq(survey.questions.first.id.to_s)
    end

    it "returns survey question and possible answer attributes" do
      survey = create(:survey, account: @account, email_enabled: true, invitation: nil)
      survey.reload

      survey.questions.first.possible_answers.order(id: :asc).each do |possible_answer|
        possible_answer.update(next_question_id: survey.questions.last.id)
      end

      expect(survey.questions.count).to eq(2)
      expect(survey.questions.first.possible_answers.count).to eq(2)

      response_payload = rack_app_as_json(serve_url, required_headers)

      first_question_and_possible_answers_object = response_payload["survey"]["first_question_and_possible_answers"]
      subsequent_questions_and_possible_answers = response_payload["survey"]["questions_and_possible_answers"]

      expect(subsequent_questions_and_possible_answers.length).to eq(1)

      questions_and_possible_answers = Array.wrap(first_question_and_possible_answers_object) + subsequent_questions_and_possible_answers

      survey.questions.each_with_index do |question, question_index|
        expect(questions_and_possible_answers[question_index]["question_id"]).to eq(question.id.to_s)
        expect(questions_and_possible_answers[question_index]["content"]).to eq(question.content)
        expect(questions_and_possible_answers[question_index]["possible_answers"].length).to eq(question.possible_answers.length)

        question.possible_answers.sort_by_position.each_with_index do |possible_answer, i|
          expect(questions_and_possible_answers[question_index]["possible_answers"][i]["possible_answer_id"]).to eq(possible_answer.id.to_s)
          expect(questions_and_possible_answers[question_index]["possible_answers"][i]["content"]).to eq(possible_answer.content)
          expect(questions_and_possible_answers[question_index]["possible_answers"][i]["next_question_id"]).to eq(possible_answer.next_question_id&.to_s)
        end
      end
    end

    it "returns free text question attributes when free text question is specified" do
      survey = create(:survey_with_one_free_question, account: @account, email_enabled: true)
      survey.reload
      survey.questions.last.update(question_type: :free_text_question, submit_label: "send response", hint_text: "feel free to type", error_text: "error!")

      response_payload = rack_app_as_json(serve_url, required_headers)

      possible_answers = response_payload["survey"]["first_question_and_possible_answers"]["possible_answers"][0]

      expect(possible_answers["possible_answer_id"]).to be_nil
      expect(possible_answers["content"]).to be_nil
      expect(possible_answers["next_question_id"]).to be_nil
      expect(possible_answers["is_free_text_question"]).to be(true)
      expect(possible_answers["question_button_label"]).to eq(survey.questions.last.submit_label)
      expect(possible_answers["max_length"]).to eq(survey.questions.last.max_length.to_s)
      expect(possible_answers["hint_text"]).to eq(survey.questions.last.hint_text)
      expect(possible_answers["error_text"]).to eq(survey.questions.last.error_text)
    end

    it "returns single choice question attributes when single choice question is specified" do
      survey = create(:survey_with_one_question, account: @account, email_enabled: true)
      survey.reload

      survey.questions.last.update(single_choice_default_label: 'select!')

      response_payload = rack_app_as_json(serve_url, required_headers)

      possible_answers = response_payload["survey"]["questions_and_possible_answers"][0]["possible_answers"][0]

      expect(possible_answers["content"]).not_to be_nil
      expect(possible_answers["next_question_id"]).to be_nil
      expect(possible_answers["single_choice_default_label"]).to eq(survey.questions.last.single_choice_default_label)
      expect(survey.reload.questions.first.possible_answers.ids).to include(possible_answers["possible_answer_id"].to_i)
    end

    it "returns image attributes when image is specified" do
      survey = create(:survey, account: @account, email_enabled: true, invitation: nil)
      survey.reload

      survey.questions[1..].each(&:destroy)
      survey.reload
      expect(survey.questions.count).to eq(1)

      answer_image_file = Rack::Test::UploadedFile.new("#{Rails.root}/spec/file_fixtures/background.jpg", "image/jpeg")

      survey.questions.first.possible_answers.order(id: :asc).each do |possible_answer|
        possible_answer.answer_image = AnswerImage.create(image: answer_image_file, imageable: @account)
        possible_answer.image_alt = "a picture I saw in a dream"
        possible_answer.image_height = "256"
        possible_answer.image_width = "128"
        possible_answer.image_width_tablet = "64"
        possible_answer.image_height_tablet = "32"
        possible_answer.image_width_mobile = "16"
        possible_answer.image_height_mobile = "8"
        possible_answer.image_position_cd = PossibleAnswer.image_position_cds.values.last

        possible_answer.save
      end

      response_payload = rack_app_as_json(serve_url, required_headers)
      first_question_possible_answers = response_payload["survey"]["first_question_and_possible_answers"]["possible_answers"]

      survey.questions.first.possible_answers.pluck(:id).each_with_index do |possible_answer_id, i|
        expect(first_question_possible_answers[i]["possible_answer_id"]).to eq(possible_answer_id.to_s)
      end

      # check that all keys values are correct
      survey.questions.first.possible_answers.map(&:answer_image).each_with_index do |answer_image, i|
        returned_url = first_question_possible_answers[i]["image_url"]

        expect(returned_url).to include(answer_image.id.to_s)
        expect(returned_url).to include(answer_image.image.file.filename)
      end
    end
  end

  describe "question ordering" do
    before do
      @account = create(:account)
      @survey = create(:survey_with_one_question, account: @account, email_enabled: true)
      @survey.questions.reload.first.possible_answers.destroy_all

      10.times do |n|
        @survey.questions.first.possible_answers << create(:possible_answer, position: n)
      end
    end

    it "returns possible answers in the order of position when no order is specified" do
      expect(@survey.questions.first.possible_answers.count).to eq(10)
      expect(@survey.questions.first.randomize).to be_nil
      response_payload = rack_app_as_json(serve_url, required_headers)
      first_question_possible_answers = response_payload["survey"]["first_question_and_possible_answers"]["possible_answers"]

      @survey.questions.first.possible_answers.sort_by_position.each_with_index do |possible_answer, i|
        expect(first_question_possible_answers[i]["possible_answer_id"]).to eq(possible_answer.id.to_s)
      end
    end

    it "returns possible answers in random ID order when randomized order is specified" do
      expect(@survey.questions.first.possible_answers.count).to eq(10)
      expect(@survey.questions.first.randomize).to be_nil
      @survey.questions.first.update(randomize: Question::RANDOMIZE_ALL)

      id_orderings = []

      5.times do
        response_payload = rack_app_as_json(serve_url, required_headers)
        first_question_possible_answers = response_payload["survey"]["first_question_and_possible_answers"]["possible_answers"]

        id_orderings << first_question_possible_answers.map { |possible_answer| possible_answer["possible_answer_id"] }
      end

      expect(id_orderings.uniq.count).not_to eq(1)
    end

    it "returns possible answers in random ID order except for the last element when 'randomize all but last' is specified" do
      expect(@survey.questions.first.possible_answers.count).to eq(10)
      expect(@survey.questions.first.randomize).to be_nil

      @survey.questions.first.update(randomize: Question::RANDOMIZE_ALL_EXCEPT_LAST)

      id_orderings = []

      5.times do
        response_payload = rack_app_as_json(serve_url, required_headers)
        first_question_possible_answers = response_payload["survey"]["first_question_and_possible_answers"]["possible_answers"]

        id_orderings << first_question_possible_answers.map { |possible_answer| possible_answer["possible_answer_id"] }
      end

      expect(id_orderings.map(&:last).uniq.count).to eq(1)

      id_orderings.map! { |ordering| ordering[0..-2] }

      expect(id_orderings.uniq.count).not_to eq(1)
    end
  end

  describe 'datetime range filtering' do
    before do
      @account = create(:account)
    end

    it "does not return surveys outside of the specified datetime range" do
      create(:survey, account: @account, email_enabled: true, starts_at: 1.year.ago, ends_at: 11.months.ago)

      it_should_not_return_survey
    end

    it "does return surveys inside of the specified datetime range" do
      create(:survey, account: @account, email_enabled: true, starts_at: 1.months.ago, ends_at: 1.months.from_now)

      it_should_return_survey
    end

    it "return surveys when no datetime range is specified" do
      create(:survey, account: @account, email_enabled: true, starts_at: nil, ends_at: nil)

      it_should_return_survey
    end
  end

  it_behaves_like "rack refire limiter" do
    def make_call(account)
      account.surveys.first.update(email_enabled: true)

      query = {
        client_key: client_key,
        device_type: "email",
        identifier: account.identifier,
        udid: udid
      }.to_query

      rack_app_as_json("/serve?#{query}", required_headers)
    end
  end

  describe 'device data trigger' do
    before do
      @device = create(:device, udid: udid)
      @account = create(:account)
      @survey = create(:survey, email_enabled: true)
      @survey.account = @account
      @survey.save
    end

    describe 'only mandatory triggers defined' do
      before do
        @survey.device_triggers.create(device_data_key: 'first', device_data_matcher: 'is', device_data_value: 'good')
        @survey.device_triggers.create(device_data_key: 'second', device_data_matcher: 'is', device_data_value: 'good')
      end

      it 'returns a survey if all of the triggers are satisfied' do
        device_data = { 'first' => 'good', 'second' => 'good' }

        it_should_return_survey(device_data)
      end

      it 'does not return a survey if one of the triggers is not satisfied' do
        device_data = { 'first' => 'good', 'second' => 'bad' }

        it_should_not_return_survey(device_data)
      end
    end

    describe 'only non-mandatory triggers defined' do
      before do
        @survey.device_triggers.create(device_data_key: 'first', device_data_matcher: 'is', device_data_value: 'good', device_data_mandatory: false)
        @survey.device_triggers.create(device_data_key: 'second', device_data_matcher: 'is', device_data_value: 'good', device_data_mandatory: false)
      end

      it 'returns a survey if one of the triggers is satisfied' do
        device_data = { 'first' => 'good', 'second' => 'bad' }

        it_should_return_survey(device_data)
      end

      it 'does not return a survey if none of the triggers are satisfied' do
        device_data = { 'first' => 'bad', 'second' => 'bad' }

        it_should_not_return_survey(device_data)
      end
    end

    describe 'mix of mandatory and non-mandatory triggers defined' do
      before do
        @survey.device_triggers.create(device_data_key: 'first', device_data_matcher: 'is', device_data_value: 'good')
        @survey.device_triggers.create(device_data_key: 'second', device_data_matcher: 'is', device_data_value: 'good', device_data_mandatory: false)
        @survey.device_triggers.create(device_data_key: 'third', device_data_matcher: 'is', device_data_value: 'good', device_data_mandatory: false)
      end

      it 'returns a survey if all of the mandatory triggers and one of the non-mandatory triggers are satisfied' do
        device_data = { 'first' => 'good', 'second' => 'bad', 'third' => 'good' }

        it_should_return_survey(device_data)
      end

      it 'does not return a survey if none of the non-mandatory triggers are satisfied' do
        device_data = { 'first' => 'good', 'second' => 'bad', 'third' => 'bad' }

        it_should_not_return_survey(device_data)
      end

      it 'does not return a survey if one of the mandatory triggers is satisfied' do
        device_data = { 'first' => 'bad', 'second' => 'bad', 'third' => 'good' }

        it_should_not_return_survey(device_data)
      end
    end
  end

  describe 'previous answer trigger' do
    before do
      @device = create(:device, udid: udid)
      @account = create(:account)
      @survey = create(:survey, account: @account, email_enabled: true)
      @other_survey = create(:survey, account: @account, status: 2, email_enabled: true)
    end

    describe 'no trigger defined' do
      it 'returns the survey' do
        it_should_return_survey
      end
    end

    describe 'trigger defined' do
      before do
        @survey.answer_triggers.create(previous_answered_survey_id: @other_survey.id,
                                       previous_possible_answer_id: @other_survey.reload.questions.first.possible_answers.first.id)
        @survey.reload
      end

      it 'does not return survey if no answer' do
        it_should_not_return_survey
      end

      it 'does not return survey if answer made by another device' do
        device2 = create(:device, udid: udid2)
        submission = create(:submission, survey: @other_survey, device: device2)

        create_answer(submission)

        it_should_not_return_survey
      end

      it 'returns the survey if answer made by right device' do
        submission = create(:submission, survey: @other_survey, device: @device)

        create_answer(submission)

        it_should_return_survey
      end

      it 'returns the survey if answer made by another device but with same client key' do
        device2 = create(:device, udid: udid2, client_key: client_key)
        @device.update(client_key: client_key)
        submission = create(:submission, survey: @other_survey, device: device2)

        create_answer(submission)

        it_should_return_survey
      end

      it 'does not return the survey if answer made by another device with different client keys' do
        device2 = create(:device, udid: udid2, client_key: 'another_client_key')
        @device.update(client_key: client_key)
        submission = create(:submission, survey: @other_survey, device: device2)

        create_answer(submission)

        it_should_not_return_survey
      end

      def create_answer(submission)
        survey = submission.survey.reload

        create(:answer,
               question: survey.questions.first,
               possible_answer: survey.questions.first.possible_answers.first,
               submission: submission)
      end
    end
  end

  it_behaves_like "serve worker argument" do
    let(:device_type) { "email" }
    let(:survey) { create(:survey, email_enabled: true) }
    let(:extra_headers) { required_headers }
  end

  describe "ServeWorker" do
    let(:survey) { create(:survey, email_enabled: true) }
    let(:account) { survey.account }

    let(:base_url) do
      "/serve?identifier=#{account.identifier}&" \
        "udid=#{udid}&" \
        "device_type=email&client_key=#{client_key}"
    end
    let(:extra_parameters) { '' }
    let(:referer_url) { 'http://localhost:3000' }
    let(:device_udid) { udid }

    before do
      @device = create(:device, udid: device_udid)

      @response = rack_app_as_json("#{base_url}#{extra_parameters}", {'Referer' => referer_url}.merge(required_headers))

      queue = Sidekiq::Queue.new
      # Nothing is queued if we didn't provide a required parameter
      @job_arguments = queue.first.try(:[], "args").try(:[], 0)
    end

    describe "custom_data" do
      subject { @job_arguments["custom_data"] }

      context "when no custom_data has been provided" do
        it { is_expected.to be_nil }
      end
    end

    describe "survey_id" do
      subject { @job_arguments["survey_id"] }

      it { is_expected.to eq survey.id.to_s }
    end

    describe "url" do
      subject { @job_arguments["url"] }

      context "when url is provided" do
        let(:extra_parameters) { "&url=#{query_url}" }
        let(:query_url) { "http://pulseinsights.com" }

        it { is_expected.to eq '' }
      end

      context "when url is not provided" do
        it { is_expected.to eq '' }
      end
    end

    describe "client_key" do
      context "when an invalid client_key has been provided" do
        let(:client_key) { 'undefined' }

        it "returns an error" do
          expect(@response).to contain_exactly("Error: Parameter 'client_key' missing")
        end
      end
    end
  end

  def serve_url
    "/serve?identifier=#{@account.identifier}&udid=#{udid}&device_type=email&client_key=#{client_key}"
  end

  def serve_call(device_data = 'null')
    uri_encoded_device_data = CGI.escape(JSON.dump(device_data))

    rack_app_as_json("#{serve_url}&device_data=#{uri_encoded_device_data}", required_headers)
  end

  def it_should_return_survey(device_data = nil)
    json_response = serve_call(device_data)

    expect(json_response['survey']['id'].to_i).not_to eq(0)
  end

  def it_should_not_return_survey(device_data = nil)
    json_response = serve_call(device_data)

    assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
  end
end
