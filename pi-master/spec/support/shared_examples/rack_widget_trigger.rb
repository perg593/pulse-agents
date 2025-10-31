# frozen_string_literal: true

# Shared examples for a rack endpoint that returns surveys according to survey triggers
RSpec.shared_examples "rack widget trigger" do
  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:udid2) { '00000000-0000-4000-f000-000000000002' }
  let(:client_key) { 'my_awesome_client_key' }

  def make_call(identifier_param, additional_query_params: {})
    raise NotImplementedError, "You must implement 'make_call' to use 'rack widget trigger'"
  end

  describe 'device triggers' do
    before do
      @device         = create(:device, udid: udid)
      @account        = create(:account)
      @bad_account    = create(:account)
      @survey         = create(:survey)
      @survey.account = @account
      @survey.save
    end

    context "when no device trigger is specified" do
      it "returns the survey if the device has no device data" do
        it_should_return_survey
      end

      context "when the device has device data" do
        before do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { age: 15 })
        end

        it "returns the survey" do
          it_should_return_survey
        end
      end
    end

    context "when a device trigger is specified" do
      context "when an 'is true' trigger is specified" do
        before do
          @survey.device_triggers.create(device_data_key: 'client', device_data_matcher: 'is_true')
        end

        context "when the device has data" do
          before do
            create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'client' => '' })
          end

          it "returns the survey" do
            it_should_return_survey
          end
        end

        context "when another device with the same client_key has the data" do
          before do
            @device.update(client_key: client_key)
            device2 = create(:device, udid: udid2, client_key: client_key)

            create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'clients' => '' })
            create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'client' => '' })
          end

          it "returns the survey" do
            it_should_return_survey(additional_query_params: {client_key: client_key})
          end
        end

        context "when the device does not have any data" do
          it "does not return the survey" do
            it_should_not_return_survey
          end
        end

        context "when the device has data not corresponding to the device_data_key trigger" do
          before do
            create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'clients' => '' })
          end

          it "does not return the survey" do
            it_should_not_return_survey
          end
        end

        context "when the device has the correct data for another account" do
          before do
            create(:device_data, device_id: @device.id, account_id: @bad_account.id, device_data: { 'client' => '' })
          end

          it "does not return the survey" do
            it_should_not_return_survey
          end
        end
      end

      context "when 'is not true' trigger" do
        before do
          @survey.device_triggers.create(device_data_key: 'client', device_data_matcher: 'is_not_true')
        end

        context "when the device has the data" do
          before do
            create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'clients' => '' })
          end

          it "returns the survey" do
            it_should_return_survey
          end
        end

        context "when another device with the same client_key has the data" do
          it "returns the survey" do
            @device.update(client_key: client_key)
            device2 = create(:device, udid: udid2, client_key: client_key)

            create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'client' => '' })
            create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'clients' => '' })

            it_should_return_survey(additional_query_params: {client_key: client_key})
          end
        end

        context "when the device has a wrong data" do
          before do
            create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'client' => '' })
          end

          it "does not return the survey" do
            it_should_not_return_survey
          end
        end

        context "when no device_data is provided" do
          before do
            create(:device_data, device_id: @device.id, account_id: @account.id, device_data: {})
          end

          it "returns the survey" do
            it_should_return_survey
          end
        end
      end

      describe "'is' trigger" do
        before do
          @survey.device_triggers.create(device_data_key: 'gender', device_data_matcher: 'is', device_data_value: 'male')
        end

        it 'returns the survey if the device has the data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'gender' => 'male' })

          it_should_return_survey
        end

        it 'returns the survey if another device with the same client_key has the data' do
          @device.update(client_key: client_key)
          device2 = create(:device, udid: udid2, client_key: client_key)

          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'gender' => 'female' })
          create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'gender' => 'male' })

          it_should_return_survey(additional_query_params: {client_key: client_key})
        end

        it 'does not return the survey if the device has a wrong data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'gender' => 'female' })

          it_should_not_return_survey
        end
      end

      describe "'is not' trigger" do
        before do
          @survey.device_triggers.create(device_data_key: 'gender', device_data_matcher: 'is_not', device_data_value: 'male')
        end

        it 'returns the survey if the device has the data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'gender' => 'female' })

          it_should_return_survey
        end

        it 'returns the survey if another device with the same client_key has the data' do
          @device.update(client_key: client_key)
          device2 = create(:device, udid: udid2, client_key: client_key)

          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'gender' => 'male' })
          create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'gender' => 'female' })

          it_should_return_survey(additional_query_params: {client_key: client_key})
        end

        it 'does not return the survey if the device has a wrong data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'gender' => 'male' })

          it_should_not_return_survey
        end
      end

      describe "contains trigger" do
        before do
          @survey.device_triggers.create(device_data_key: 'id', device_data_matcher: 'contains', device_data_value: '11')
        end

        it 'returns the survey if the device has the data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '0000110000' })

          it_should_return_survey
        end

        it 'returns the survey if another device with the same client_key has the data' do
          @device.update(client_key: client_key)
          device2 = create(:device, udid: udid2, client_key: client_key)

          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '1234567890' })
          create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'id' => '0000110000' })

          it_should_return_survey(additional_query_params: {client_key: client_key})
        end

        it 'does not return the survey if the device has a wrong data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '1234567890' })

          it_should_not_return_survey
        end
      end

      describe "'does not contain' trigger" do
        before do
          @survey.device_triggers.create(device_data_key: 'id', device_data_matcher: 'does_not_contain', device_data_value: 'abc')
        end

        it 'returns the survey if the device has the data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '12345' })

          it_should_return_survey
        end

        it 'returns the survey if another device with the same client_key has the data' do
          @device.update(client_key: client_key)
          device2 = create(:device, udid: udid2, client_key: client_key)

          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => 'abcdefgh' })
          create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'id' => '12345' })

          it_should_return_survey(additional_query_params: {client_key: client_key})
        end

        it 'does not return the survey if the device has a wrong data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => 'abcdefgh' })

          it_should_not_return_survey
        end
      end

      describe '> trigger' do
        before do
          @survey.device_triggers.create(device_data_key: 'id', device_data_matcher: 'is_more_than', device_data_value: '10')
        end

        it 'returns the survey if the device has the data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '15' })

          it_should_return_survey
        end

        it 'returns the survey if another device with the same client_key has the data' do
          @device.update(client_key: client_key)
          device2 = create(:device, udid: udid2, client_key: client_key)

          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '5' })
          create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'id' => '15' })

          it_should_return_survey(additional_query_params: {client_key: client_key})
        end

        it 'does not return the survey if the device has a wrong data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '5' })

          it_should_not_return_survey
        end
      end

      describe '>= trigger' do
        before do
          @survey.device_triggers.create(device_data_key: 'id', device_data_matcher: 'is_equal_or_more_than', device_data_value: '10')
        end

        it 'returns the survey if the device has the data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '10' })

          it_should_return_survey
        end

        it 'returns the survey if another device with the same client_key has the data' do
          @device.update(client_key: client_key)
          device2 = create(:device, udid: udid2, client_key: client_key)

          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '5' })
          create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'id' => '10' })

          it_should_return_survey(additional_query_params: {client_key: client_key})
        end

        it 'does not return the survey if the device has a wrong data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '5' })

          it_should_not_return_survey
        end
      end

      describe '< trigger' do
        before do
          @survey.device_triggers.create(device_data_key: 'id', device_data_matcher: 'is_less_than', device_data_value: '10')
        end

        it 'returns the survey if the device has the data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '5' })

          it_should_return_survey
        end

        it 'returns the survey if another device with the same client_key has the data' do
          @device.update(client_key: client_key)
          device2 = create(:device, udid: udid2, client_key: client_key)

          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '15' })
          create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'id' => '5' })

          it_should_return_survey(additional_query_params: {client_key: client_key})
        end

        it 'does not return the survey if the device has a wrong data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '15' })

          it_should_not_return_survey
        end
      end

      describe '<= trigger' do
        before do
          @survey.device_triggers.create(device_data_key: 'id', device_data_matcher: 'is_equal_or_less_than', device_data_value: '10')
        end

        it 'returns the survey if the device has the data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '10' })

          it_should_return_survey
        end

        it 'returns the survey if another device with the same client_key has the data' do
          @device.update(client_key: client_key)
          device2 = create(:device, udid: udid2, client_key: client_key)

          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '15' })
          create(:device_data, device_id: device2.id, account_id: @account.id, device_data: { 'id' => '10' })

          it_should_return_survey(additional_query_params: {client_key: client_key})
        end

        it 'does not return the survey if the device has a wrong data' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '15' })

          it_should_not_return_survey
        end
      end

      describe 'multiple triggers' do
        before do
          @survey.device_triggers.create(device_data_key: 'id', device_data_matcher: 'is_equal_or_less_than', device_data_value: '10')
          @survey.device_triggers.create(device_data_key: 'age', device_data_matcher: 'is_equal', device_data_value: '20')
          @survey.device_triggers.create(device_data_key: 'gender', device_data_matcher: 'is', device_data_value: 'male')
          @survey.device_triggers.create(device_data_key: 'client', device_data_matcher: 'is_true')
        end

        it 'returns the survey if every triggers are present' do
          create(:device_data,
                 device_id: @device.id,
                 account_id: @account.id,
                 device_data: { 'id' => '10', 'age' => '20', 'gender' => 'male', 'client' => 'true' })

          it_should_return_survey
        end

        it 'returns the survey if another device with the same client_key has the data' do
          @device.update(client_key: client_key)
          device2 = create(:device, udid: udid2, client_key: client_key)

          create(:device_data,
                 device_id: @device.id,
                 account_id: @account.id,
                 device_data: { 'id' => '10', 'age' => '20', 'gender' => 'female', 'client' => 'true' })
          create(:device_data,
                 device_id: device2.id,
                 account_id: @account.id,
                 device_data: { 'id' => '10', 'age' => '20', 'gender' => 'male', 'client' => 'true' })

          it_should_return_survey(additional_query_params: {client_key: client_key})
        end

        it 'does not return the survey if at least one trigger is missing' do
          create(:device_data, device_id: @device.id, account_id: @account.id, device_data: { 'id' => '10', 'age' => '20', 'gender' => 'male' })

          it_should_not_return_survey
        end
      end
    end
  end

  describe "previous answer trigger" do
    let(:other_survey_first_possible_answer) { @other_survey.reload.questions.first.possible_answers.first }

    before do
      @device               = create(:device, udid: udid)
      @account              = create(:account)
      @bad_account          = create(:account)
      @survey               = create(:survey, account: @account)
      @other_survey         = create(:survey, status: 2, account: @account)
    end

    context "when none defined" do
      it "returns the survey" do
        it_should_return_survey
      end
    end

    context "when defined" do
      before do
        @survey.answer_triggers.create(previous_answered_survey_id: @other_survey.id,
                                       previous_possible_answer_id: @other_survey.reload.questions.first.possible_answers.first.id)
        @survey.reload
      end

      it "does not return survey if no answer" do
        it_should_not_return_survey
      end

      context "when answer made by another device" do
        before do
          device2 = create(:device, udid: udid2)
          submission = create(:submission, survey: @other_survey, device: device2)
          create(:answer, question: @other_survey.reload.questions.first,
                 possible_answer: other_survey_first_possible_answer, submission: submission)
        end

        it "does not return survey" do
          it_should_not_return_survey
        end
      end

      context "when answer made by right device" do
        before do
          submission = create(:submission, survey: @other_survey, device: @device)

          create(:answer, question: @other_survey.reload.questions.first,
                 possible_answer: other_survey_first_possible_answer, submission: submission)
        end

        it "returns the survey" do
          it_should_return_survey
        end
      end

      context "when answer made by another device but with same client key" do
        before do
          device2 = create(:device, udid: udid2, client_key: client_key)
          @device.update(client_key: client_key)
          submission = create(:submission, survey: @other_survey, device: device2)

          create(:answer, question: @other_survey.reload.questions.first,
                 possible_answer: other_survey_first_possible_answer, submission: submission)
        end

        it "returns the survey" do
          it_should_return_survey(additional_query_params: {client_key: client_key})
        end
      end

      context "when answer made by another device with different client keys" do
        before do
          device2 = create(:device, udid: udid2, client_key: 'another_client_key')
          @device.update(client_key: client_key)
          submission = create(:submission, survey: @other_survey, device: device2)

          create(:answer, question: @other_survey.reload.questions.first,
                 possible_answer: other_survey_first_possible_answer, submission: submission)
        end

        it "does not return the survey" do
          it_should_not_return_survey(additional_query_params: {client_key: client_key})
        end
      end
    end
  end

  describe 'custom data triggers' do
    let(:survey) { create(:survey, account: @account) }

    before do
      @account = create(:account)
    end

    describe 'mandatory triggers' do
      before do
        survey.device_triggers.create(device_data_key: 'a', device_data_value: '1', device_data_matcher: 'is_more_than', device_data_mandatory: true)
        survey.device_triggers.create(device_data_key: 'b', device_data_value: 'foo', device_data_matcher: 'contains', device_data_mandatory: true)
      end

      context 'when custom data satisfies all of the mandatory triggers' do
        it 'returns a survey' do
          custom_data = { a: '3', b: 'foobar' }

          it_should_return_survey(additional_query_params: {custom_data: custom_data.to_json})
        end
      end

      context 'when custom data does not satisfy one of the mandatory triggers' do
        it 'does not return a survey' do
          custom_data = { a: '1', b: 'foobar' }

          it_should_not_return_survey(additional_query_params: {custom_data: custom_data.to_json})
        end
      end
    end

    describe 'optional triggers' do
      before do
        survey.device_triggers.create(device_data_key: 'a', device_data_value: '1', device_data_matcher: 'is_more_than', device_data_mandatory: false)
        survey.device_triggers.create(device_data_key: 'b', device_data_value: 'foo', device_data_matcher: 'contains', device_data_mandatory: false)
      end

      context 'when custom data satisfies one of the optional triggers' do
        it 'returns a survey' do
          custom_data = { a: '1', b: 'foobar' }

          it_should_return_survey(additional_query_params: {custom_data: custom_data.to_json})
        end
      end

      context 'when custom data satisfies none of the optional triggers' do
        it 'does not return a survey' do
          custom_data = { a: '1', b: 'bar' }

          it_should_not_return_survey(additional_query_params: {custom_data: custom_data.to_json})
        end
      end
    end

    context 'when custom data satisfies all of the optional triggers but one mandatory trigger' do
      it 'does not return a survey' do
        survey.device_triggers.create(device_data_key: 'a', device_data_value: '1', device_data_matcher: 'is_more_than', device_data_mandatory: false)
        survey.device_triggers.create(device_data_key: 'b', device_data_value: 'foo', device_data_matcher: 'contains', device_data_mandatory: false)
        survey.device_triggers.create(device_data_key: 'c', device_data_matcher: 'is_true', device_data_mandatory: true)

        custom_data = { a: '3', b: 'foobar' }

        it_should_not_return_survey(additional_query_params: {custom_data: custom_data.to_json})
      end
    end
  end

  def json_response(additional_query_params)
    parse_json_response(make_call(@account, additional_query_params: additional_query_params).body)
  end

  def it_should_return_survey(additional_query_params: {})
    expect(json_response(additional_query_params).dig("survey", "id").to_i).not_to eq(0)
  end

  def it_should_not_return_survey(additional_query_params: {})
    assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response(additional_query_params)
  end
end
