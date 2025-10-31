# frozen_string_literal: true
require 'spec_helper'

describe Control::QuestionsController do
  before do
    Account.delete_all
    User.delete_all
    Invitation.delete_all
    Survey.delete_all
    Question.delete_all
    Tag.delete_all
  end

  describe "Record requirement" do
    before do
      sign_in create(:user)
    end

    it "redirects to the survey dashboard when the question is not found" do
      endpoints = [
        { verb: :post, url: :auto_tag_answers, json: :always },
        { verb: :patch, url: :toggle_tag_automation_worker, json: :always },
        { verb: :patch, url: :update }
      ]

      endpoints.each do |endpoint|
        it_handles_missing_records(endpoint)
      end
    end

    it "redirects to the survey dashboard when the survey locale group is not found" do
      endpoints = [
        { verb: :post, url: :create }
      ]

      endpoints.each do |endpoint|
        it_handles_missing_records(endpoint, custom_id: :survey_locale_group_id)
      end
    end
  end

  describe "POST #create" do
    subject :post_create do
      post :create, params: {
        survey_locale_group_id: @base_survey.survey_locale_group_id,
        question_locale_group_name: "question locale group name",
        question: {
          content: "new question content"
        },
        for_base_survey: true
      }
    end

    it "is not available to reporting level users" do
      user = create(:reporting_only_user)
      sign_in user

      @base_survey = create(:localized_survey, account: user.account)

      post_create

      it_redirects_to_dashboard
    end

    it 'is not possible for users not belonging to the account that owns the SurveyLocaleGroup' do
      user = create(:user)
      sign_in user

      @base_survey = create(:localized_survey, account: create(:account))

      post_create

      it_redirects_to_dashboard
    end

    it 'is possible for full access users' do
      user = create(:user)
      sign_in user

      @base_survey = create(:localized_survey, account: user.account)

      post_create

      it_redirects_to_localization_editor
    end

    it "creates new Question and QuestionLocaleGroup records when all required fields are provided" do
      user = create(:user)
      sign_in user

      @base_survey = create(:localized_survey, account: user.account)

      old_question_count = Question.count
      old_question_locale_group_count = QuestionLocaleGroup.count

      post_create

      it_redirects_to_localization_editor

      expect(Question.count).to eq(old_question_count + 1)
      expect(QuestionLocaleGroup.count).to eq(old_question_locale_group_count + 1)
    end

    describe "associated records" do
      let(:account) { create(:account) }
      let(:user) { create(:user, account: account) }

      before do
        sign_in user

        @base_survey = create(:localized_survey, account: account)
        @old_num_questions = @base_survey.questions.count
      end

      [
        :slider_question,
        :multiple_choices_question,
        :single_choice_question
      ].each do |question_type|
        context "when a #{question_type}" do
          before do
            post :create, params: {
              survey_locale_group_id: @base_survey.survey_locale_group_id,
              question_locale_group_name: "New question QALG",
              question: {
                content: "new question content",
                question_type: Question.question_types[question_type]
              },
              for_base_survey: true
            }

            @base_survey.questions.reload
          end

          it "creates a #{question_type}" do
            questions = @base_survey.questions

            expect(questions.count).to eq @old_num_questions + 1
            expect(questions.last.question_type).to eq question_type.to_s
            expect(questions.last.nps).to be false
          end

          it "creates 2 possible answers each with its own possible answer locale group" do
            possible_answers = @base_survey.questions.last.possible_answers

            expect(possible_answers.count).to eq 2
            possible_answers.each do |possible_answer|
              expect(possible_answer.possible_answer_locale_group.present?).to be true
            end

            expect(possible_answers.pluck(:possible_answer_locale_group_id).uniq.count).to eq 2
          end
        end
      end

      context "when an NPS question" do
        before do
          post :create, params: {
            survey_locale_group_id: @base_survey.survey_locale_group_id,
            question_locale_group_name: "New NPS question QALG",
            question: {
              content: "new question content",
              question_type: Question.question_types[:single_choice_question],
              nps: "true"
            },
            for_base_survey: true
          }

          @base_survey.questions.reload
        end

        it "creates an NPS question" do
          questions = @base_survey.questions

          expect(questions.count).to eq @old_num_questions + 1
          expect(questions.last.question_type).to eq "single_choice_question"
          expect(questions.last.nps).to be true
        end

        it "creates 10 possible answers each with its own possible answer locale group" do
          possible_answers = @base_survey.questions.last.possible_answers

          expect(possible_answers.count).to eq 11
          possible_answers.each do |possible_answer|
            expect(possible_answer.possible_answer_locale_group.present?).to be true
          end

          expect(possible_answers.pluck(:possible_answer_locale_group_id).uniq.count).to eq 11
        end
      end
    end

    describe 'question routing' do
      before do
        user = create(:user)
        sign_in user
        @base_survey = create(:localized_survey, account: user.account)
        @base_survey.reload

        @new_survey = @base_survey.duplicate
        @new_survey.save

        @num_base_survey_questions = @base_survey.questions.count
        @num_new_survey_questions = @new_survey.questions.count
      end

      describe "for questions that don't yet exist" do
        # rubocop:disable RSpec/ExampleLength # this will be shorter when we stop distinguishing between
        # free_text_next_question_id and next_question_id
        it "retroactively applies free text question routing to new questions in non-base survey" do
          2.times do
            post :create, params: {
              survey_locale_group_id: @base_survey.survey_locale_group_id,
              question_locale_group_name: FFaker::Lorem.phrase,
              question: {
                content: FFaker::Lorem.phrase,
                question_type: Question.question_types["free_text_question"]
              },
              for_base_survey: true
            }
          end

          @base_survey.questions.reload
          @base_survey.questions[-2].update(free_text_next_question_id: @base_survey.questions[-1].id)

          expect(@base_survey.questions.count).to eq(@num_base_survey_questions + 2)
          expect(@new_survey.questions.count).to eq(@num_new_survey_questions)

          question_locale_group = @base_survey.questions[-2].question_locale_group

          post :create, params: {
            survey: {
              survey_locale_group_id: @base_survey.survey_locale_group.id,
              question: {
                "0" => {
                  survey_id: @new_survey.id,
                  content: FFaker::Lorem.phrase,
                  question_locale_group_id: question_locale_group.id
                }
              }
            },
            for_localized_survey: true
          }

          @new_survey.questions.reload
          expect(@new_survey.questions.count).to eq(@num_new_survey_questions + 1)
          expect(@new_survey.questions.last.free_text_question?).to be(true)
          expect(@new_survey.questions.last.free_text_next_question_id).to be_nil

          question_locale_group = @base_survey.questions[-1].question_locale_group

          post :create, params: {
            survey: {
              survey_locale_group_id: @base_survey.survey_locale_group.id,
              question: {
                "0" => {
                  survey_id: @new_survey.id,
                  content: FFaker::Lorem.phrase,
                  question_locale_group_id: question_locale_group.id
                }
              }
            },
            for_localized_survey: true
          }

          @new_survey.questions.reload
          expect(@new_survey.questions.count).to eq(@num_new_survey_questions + 2)
          expect(@new_survey.questions.last.free_text_question?).to be(true)

          expect(@new_survey.questions[-2].free_text_next_question_id).to eq(@new_survey.questions.last.id)
        end

        it "retroactively applies multiple choice question routing to new questions in non-base survey" do
          2.times do
            post :create, params: {
              survey_locale_group_id: @base_survey.survey_locale_group_id,
              question_locale_group_name: FFaker::Lorem.phrase,
              question: {
                content: FFaker::Lorem.phrase,
                question_type: Question.question_types["multiple_choices_question"]
              },
              for_base_survey: true
            }
          end

          @base_survey.questions.reload
          @base_survey.questions[-2].update(next_question_id: @base_survey.questions[-1].id)

          expect(@base_survey.questions.count).to eq(@num_base_survey_questions + 2)
          expect(@new_survey.questions.count).to eq(@num_new_survey_questions)

          question_locale_group = @base_survey.questions[-2].question_locale_group

          post :create, params: {
            survey: {
              survey_locale_group_id: @base_survey.survey_locale_group.id,
              question: {
                "0" => {
                  survey_id: @new_survey.id,
                  content: FFaker::Lorem.phrase,
                  question_locale_group_id: question_locale_group.id
                }
              }
            },
            for_localized_survey: true
          }

          @new_survey.questions.reload
          expect(@new_survey.questions.count).to eq(@num_new_survey_questions + 1)
          expect(@new_survey.questions.last.question_type == "multiple_choices_question").to be(true)
          expect(@new_survey.questions.last.next_question_id).to be_nil

          question_locale_group = @base_survey.questions[-1].question_locale_group

          post :create, params: {
            survey: {
              survey_locale_group_id: @base_survey.survey_locale_group.id,
              question: {
                "0" => {
                  survey_id: @new_survey.id,
                  content: FFaker::Lorem.phrase,
                  question_locale_group_id: question_locale_group.id
                }
              }
            },
            for_localized_survey: true
          }

          @new_survey.questions.reload
          expect(@new_survey.questions.count).to eq(@num_new_survey_questions + 2)
          expect(@new_survey.questions.last.question_type == "multiple_choices_question").to be(true)

          expect(@new_survey.questions[-2].next_question_id).to eq(@new_survey.questions.last.id)
        end
      end

      it 'applies free text question routing to new questions in non-base survey' do
        post :create, params: {
          survey_locale_group_id: @base_survey.survey_locale_group_id,
          question_locale_group_name: "question locale group name",
          question: {
            content: "new question content",
            question_type: Question.question_types["free_text_question"]
          },
          next_question_locale_group_id: @base_survey.questions.first.question_locale_group_id,
          for_base_survey: true
        }

        @base_survey.questions.reload

        expect(@base_survey.questions.count).to eq(@num_base_survey_questions + 1)
        expect(@new_survey.questions.count).to eq(@num_new_survey_questions)

        @question_locale_group = @base_survey.questions.last.question_locale_group

        post :create, params: {
          survey: {
            survey_locale_group_id: @base_survey.survey_locale_group.id,
            question: {
              "0" => {
                survey_id: @new_survey.id,
                content: 'bonjour',
                question_locale_group_id: @base_survey.questions.last.question_locale_group_id
              }
            }
          },
          for_localized_survey: true
        }

        expect(@new_survey.questions.count).to eq(@num_new_survey_questions + 1)
        expect(@base_survey.questions.last.free_text_next_question_id).to eq(@base_survey.questions.first.id)

        @new_survey.questions.reload
        expect(@new_survey.questions.last.free_text_question?).to be(true)
        expect(@new_survey.questions.last.free_text_next_question_id).to eq(@new_survey.questions.first.id)
      end

      it 'applies multiple choice question routing to new questions in non-base survey' do
        post :create, params: {
          survey_locale_group_id: @base_survey.survey_locale_group.id,
          question_locale_group_name: "question locale group name",
          question: {
            content: "test",
            question_type: Question.question_types["multiple_choices_question"]
          },
          next_question_locale_group_id: @base_survey.questions.first.question_locale_group_id,
          for_base_survey: true
        }

        @base_survey.questions.reload

        expect(@base_survey.questions.count).to eq(@num_base_survey_questions + 1)
        expect(@new_survey.questions.count).to eq(@num_new_survey_questions)

        post :create, params: {
          survey: {
            survey_locale_group_id: @base_survey.survey_locale_group.id,
            question: {
              "0" => {
                content: "test",
                question_locale_group_id: @base_survey.questions.last.question_locale_group_id,
                survey_id: @new_survey.id
              }
            }
          },
          for_localized_survey: true
        }

        expect(@new_survey.questions.count).to eq(@num_new_survey_questions + 1)
        expect(@base_survey.questions.last.next_question_id).to eq(@base_survey.questions.first.id)

        @new_survey.questions.reload
        expect(@new_survey.questions.last.question_type).to eq('multiple_choices_question')
        expect(@new_survey.questions.last.next_question_id).to eq(@new_survey.questions.first.id)
      end

      it 'applies possible answer routing to new questions in non-base survey' do
        post :create, params: {
          survey_locale_group_id: @base_survey.survey_locale_group.id,
          question_locale_group_name: "question locale group name",
          question: {
            content: "test",
            question_type: Question.question_types["multiple_choices_question"]
          },
          next_question_locale_group_id: @base_survey.questions.first.question_locale_group_id,
          for_base_survey: true
        }

        @base_survey.questions.reload

        expect(@base_survey.questions.count).to eq(@num_base_survey_questions + 1)
        expect(@new_survey.questions.count).to eq(@num_new_survey_questions)

        # add a new possible answer to both the base and localized surveys
        # pointing to the new question
        possible_answer_locale_group = create(
          :possible_answer_locale_group,
          owner_record_id: @base_survey.questions.first.question_locale_group_id
        )

        create(
          :possible_answer,
          question: @base_survey.questions.first,
          possible_answer_locale_group_id: possible_answer_locale_group.id,
          next_question_id: @base_survey.questions.last.id
        )
        @base_survey.questions.reload

        create(
          :possible_answer,
          question: @new_survey.questions.first,
          possible_answer_locale_group_id: possible_answer_locale_group.id
        )
        @new_survey.questions.reload

        # now create the new question in the localized survey
        post :create, params: {
          survey: {
            survey_locale_group_id: @base_survey.survey_locale_group.id,
            question: {
              "0" => {
                content: "test",
                question_locale_group_id: @base_survey.questions.last.question_locale_group_id,
                survey_id: @new_survey.id
              }
            }
          },
          for_localized_survey: true
        }

        expect(@new_survey.questions.count).to eq(@num_new_survey_questions + 1)
        expect(@base_survey.questions.first.possible_answers.last.next_question_id).to eq(@base_survey.questions.last.id)

        @new_survey.questions.reload
        expect(@new_survey.questions.first.possible_answers.last.next_question_id).to eq(@new_survey.questions.last.id)
      end
    end

    it "sets free_text_next_question_id for free text questions" do
      user = create(:user)
      sign_in user

      base_survey = create(:survey_without_question, account: user.account, language_code: "en_ca")

      q1 = create(:question, survey_id: base_survey.id, position: 0)

      base_survey.reload
      base_survey.localize!

      q1.reload

      post :create, params: {
        survey_locale_group_id: base_survey.survey_locale_group_id,
        question_locale_group_name: "question locale group name",
        next_question_locale_group_id: q1.question_locale_group_id,
        question: {
          question_type: Question.question_types["free_text_question"],
          content: "new question content"
        },
        for_base_survey: true
      }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))

      base_survey.reload
      base_survey.questions.reload
      expect(base_survey.questions.last.free_text_next_question_id).to eq q1.id
    end

    it "does not create new Question and QuestionLocaleGroup records when a required field is not provided" do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      old_question_count = Question.count
      old_question_locale_group_count = QuestionLocaleGroup.count

      required_params = {
        survey_locale_group_id: base_survey.survey_locale_group_id,
        question_locale_group_name: "question locale group name",
        question: {
          content: "new question content"
        },
        for_base_survey: true
      }

      post :create, params: required_params.merge(survey_locale_group_id: nil)

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(dashboard_url)

      expect(Question.count).to eq(old_question_count)
      expect(QuestionLocaleGroup.count).to eq(old_question_locale_group_count)

      post :create, params: required_params.deep_merge(question: { content: nil })

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))

      expect(Question.count).to eq(old_question_count)
      expect(QuestionLocaleGroup.count).to eq(old_question_locale_group_count)

      post :create, params: required_params.deep_merge(question_locale_group_name: nil)

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))

      expect(Question.count).to eq(old_question_count)
      expect(QuestionLocaleGroup.count).to eq(old_question_locale_group_count)
    end
  end

  describe "PATCH #update" do
    it "updates the question for full access users" do
      @user = create(:user)
      sign_in @user
      @survey = create(:survey, account: @user.account)
      @question = create(:custom_content_question, survey: @survey)

      request.env['HTTP_REFERER'] = 'http://example.com' # For "redirect_to :back"

      patch :update, params: { id: @question.id, question: {custom_content: '<p>New Content</p>' } }

      expect(@question.reload.custom_content).to eq('<p>New Content</p>')
    end

    it "does not update the question for reporting only users" do
      @user = create(:reporting_only_user)
      sign_in @user
      @survey = create(:survey, account: @user.account)
      @question = create(:custom_content_question, survey: @survey)

      patch :update, params: { id: @question.id, question: {custom_content: '<p>New Content</p>' } }

      expect(@question.reload.custom_content).not_to eq('<p>New Content</p>')
    end
  end

  describe 'POST #create_tag' do
    let(:account) { create(:account) }
    let(:question) { create(:free_text_question, survey: create(:survey, account: account)) }

    before do
      sign_in create(:user, account: account)
    end

    context 'when question belongs to a different account' do
      before do
        # rubocop:disable Rspec/AnyInstance - Endpoints behave differently based on `request.xhr?`
        allow_any_instance_of(ActionDispatch::Request).to receive(:xhr?).and_return(true)
      end

      it 'returns "not found"' do
        patch :create_tag, params: { id: create(:question).id }
        expect(response).to have_http_status :not_found
      end
    end

    context 'when tag will not be valid' do
      it 'returns "internal server error"' do
        patch :create_tag, params: { id: question.id, tag: { name: '', color: '' } }
        expect(response).to have_http_status :internal_server_error
      end
    end

    it "creates a tag with given name and color" do
      tag_name = FFaker::Lorem.word
      tag_color = FFaker::Color.name

      expect do
        patch :create_tag, params: { id: question.id, name: tag_name, color: tag_color }
      end.to change { Tag.count }.from(0).to(1)

      tag_attributes = JSON.parse(response.body)
      expect(tag_attributes['id']).to eq Tag.first.id
      expect(tag_attributes['text']).to eq tag_name
      expect(tag_attributes['color']).to eq tag_color
    end
  end

  describe 'PATCH #update_tag' do
    let(:account) { create(:account) }
    let(:question) { create(:free_text_question, survey: create(:survey, account: account)) }

    before do
      sign_in create(:user, account: account)
    end

    context 'when question belongs to a different account' do
      before do # - Endpoints behave differently based on `request.xhr?`
        allow_any_instance_of(ActionDispatch::Request).to receive(:xhr?).and_return(true)
      end

      it 'returns "not found"' do
        patch :update_tag, params: { id: create(:question).id }
        expect(response).to have_http_status :not_found
      end
    end

    context 'when tag belongs to a different question' do
      before do # - Endpoints behave differently based on `request.xhr?`
        allow_any_instance_of(ActionDispatch::Request).to receive(:xhr?).and_return(true)
      end

      it 'returns "not found"' do
        patch :update_tag, params: { id: question.id, tag_id: create(:tag).id }
        expect(response).to have_http_status :not_found
      end
    end

    it "updates a tag's name and color" do
      tag = create(:tag, question: question)

      tag_name_after = FFaker::Lorem.word
      tag_color_after = FFaker::Color.name
      patch :update_tag, params: { id: question.id, tag_id: tag.id, tag: { name: tag_name_after, color: tag_color_after } }

      tag_attributes = JSON.parse(response.body)
      expect(tag_attributes['id']).to eq tag.id
      expect(tag_attributes['text']).to eq tag_name_after
      expect(tag_attributes['color']).to eq tag_color_after
    end
  end

  describe 'DELETE #delete_tag' do
    let(:account) { create(:account) }
    let(:question) { create(:free_text_question, survey: create(:survey, account: account)) }

    before do
      sign_in create(:user, account: account)
    end

    context 'when question belongs to a different account' do
      before do # - Endpoints behave differently based on `request.xhr?`
        allow_any_instance_of(ActionDispatch::Request).to receive(:xhr?).and_return(true)
      end

      it 'returns "not found"' do
        patch :delete_tag, params: { id: create(:question).id }
        expect(response).to have_http_status :not_found
      end
    end

    context 'when tag belongs to a different question' do
      before do # - Endpoints behave differently based on `request.xhr?`
        allow_any_instance_of(ActionDispatch::Request).to receive(:xhr?).and_return(true)
      end

      it 'returns "not found"' do
        patch :delete_tag, params: { id: question.id, tag_id: create(:tag).id }
        expect(response).to have_http_status :not_found
      end
    end

    it "deletes a tag" do
      tag = create(:tag, question: question)
      expect do
        patch :delete_tag, params: { id: question.id, tag_id: tag.id }
      end.to change { Tag.count }.from(1).to(0)

      tag_attributes = JSON.parse(response.body)
      expect(tag_attributes['tagId']).to eq tag.id
    end
  end

  describe "GET #text_responses" do
    it_behaves_like "shared authorization" do
      let(:account) { create(:account) }
      let(:survey) { create(:survey, account: account) }
      let(:question) { create(:question, survey: survey) }

      def make_call
        get :text_responses, params: { question_id: question.id }
      end

      def reporting_only_assertion
        assert_response 200
      end
    end
  end

  describe "POST #auto_tag_answers" do
    let(:account) { create(:account, tag_automation_enabled: true) }
    let(:user) { create(:user, account: account) }

    let(:question) { create(:question, survey: create(:survey, account: account)) }

    it_behaves_like "shared authorization" do
      before do # - Endpoints behave differently based on `request.xhr?`
        allow_any_instance_of(ActionDispatch::Request).to receive(:xhr?).and_return(true)
      end

      def make_call
        post :auto_tag_answers, params: {
          id: question.id,
          tag_automation_job: {
            tag_automation_job_answers_attributes: {
              '0': { answer_id: create(:answer, question: question).id }
            }
          }
        }
      end

      def not_signed_in_assertion
        assert_response :unauthorized
      end

      def admin_wrong_account_assertion
        assert_response 404
      end

      def full_access_wrong_account_assertion
        assert_response 404
      end
    end

    context "when the account does not have autotag enabled" do
      before do
        account.update(tag_automation_enabled: false)

        sign_in user

        post :auto_tag_answers, params: { id: question.id }
      end

      it "fails" do
        assert_response 403
      end
    end

    it 'returns the id of a tag_automation_job' do
      sign_in user

      expect do
        post :auto_tag_answers, params: {
          id: question.id,
          tag_automation_job: {
            tag_automation_job_answers_attributes: {
              '0': { answer_id: create(:answer, question: question).id }
            }
          }
        }
      end.to change { TagAutomationJob.count }.from(0).to(1)

      expect(JSON.parse(response.body)['tagAutomationJobId']).to eq TagAutomationJob.first.id
    end
  end

  describe "PATCH #toggle_tag_automation_worker" do
    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }
    let(:survey) { create(:survey, account: account) }

    before do
      sign_in user

      patch :toggle_tag_automation_worker, params: { id: survey.questions.first.id, question: { tag_automation_worker_enabled: true } }
    end

    context "when the account does not have autotag enabled" do
      let(:account) { create(:account, tag_automation_enabled: false) }

      it "fails" do
        assert_response 403

        expect(survey.questions.first.tag_automation_worker_enabled).to be false
      end
    end

    context "when the account has autotag enabled" do
      let(:account) { create(:account, tag_automation_enabled: true) }

      it "succeeds" do
        assert_response 204

        expect(survey.questions.first.tag_automation_worker_enabled).to be true
      end
    end
  end

  def it_redirects_to_dashboard
    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to eq(dashboard_url)
  end

  def it_redirects_to_localization_editor
    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to eq(localization_editor_url(@base_survey.survey_locale_group_id))
  end
end
