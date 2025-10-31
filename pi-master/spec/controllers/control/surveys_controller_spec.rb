# frozen_string_literal: true
require 'filter_spec_helper'
require 'spec_helper'
include Control::FiltersHelper
include Control::DatesHelper

describe Control::SurveysController do
  let(:timezone) { ActiveSupport::TimeZone['GMT'] }
  let(:diagram_properties_attributes) do
    {
      id: "",
      position: [100, 200]
    }
  end

  before do
    Account.delete_all
    User.delete_all
    Invitation.delete_all
    Survey.delete_all
    Question.delete_all
    PossibleAnswer.delete_all
    Submission.delete_all
    Answer.delete_all
    Tag.delete_all
    AppliedTag.delete_all
  end

  describe "Record requirements" do
    before do
      sign_in create(:user)
    end

    it "redirects to the survey dashboard when the survey is not found" do
      endpoints = [
        { verb: :get, url: :ajax_report, json: :always },
        { verb: :get, url: :background_report_metrics, json: :always },
        { verb: :get, url: :background_report_stats, json: :always },
        { verb: :patch, url: :change_status },
        { verb: :get, url: :destroy, json: :conditional },
        { verb: :post, url: :duplicate, json: :conditional },
        { verb: :get, url: :edit },
        { verb: :get, url: :page_event_data, json: :always },
        { verb: :delete, url: :remove_background },
        { verb: :get, url: :report },
        { verb: :get, url: :survey_index_localization_modal },
        { verb: :get, url: :trend_report_data, json: :always },
        { verb: :get, url: :update, json: :conditional },
        { verb: :get, url: :url_builder }
      ]

      endpoints.each do |endpoint|
        it_handles_missing_records(endpoint)
      end
    end

    it "redirects to the survey dashboard when the survey locale group is not found" do
      endpoints = [
        { verb: :post, url: :localization_base_update, json: :always },
        { verb: :post, url: :localization_content_update, json: :conditional },
        { verb: :post, url: :localization_duplicate, json: :conditional },
        { verb: :get, url: :localization_editor },
        { verb: :get, url: :localization_report },
        { verb: :get, url: :localization_report_metrics, json: :always },
        { verb: :get, url: :localization_report_stats, json: :always },
        { verb: :post, url: :localization_update, json: :conditional }
      ]

      endpoints.each do |endpoint|
        it_handles_missing_records(endpoint, custom_id: :survey_locale_group_id)
      end
    end

    it "redirects to the survey dashboard when the question is not found" do
      get :free_text_answers, params: { id: 1, question_id: -1 }

      assert_response 302
      assert_redirected_to dashboard_url
    end
  end

  describe "GET #index" do
    it "renders the surveys listing to full access users" do
      sign_in create(:user)

      get :index
      expect(response).to have_http_status(:ok)
    end

    it "renders the surveys listing to reporting only users" do
      sign_in create(:reporting_only_user)

      get :index
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #new" do
    it "renders the new form to full access users" do
      sign_in create(:user)

      get :new

      expect(response).to have_http_status(:ok)
    end

    it "does not render the new form to reporting only users" do
      sign_in create(:reporting_only_user)

      get :new

      expect_redirected_to_dashboard
    end
  end

  describe "GET #edit" do
    let(:survey) { create(:survey, account: user.account) }

    before do
      sign_in user

      get :edit, params: { id: survey.id }
    end

    context "when the user has full access" do
      let(:user) { create(:user) }

      it "renders the edit page" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is reporting-only" do
      let(:user) { create(:reporting_only_user) }

      it "renders the edit page" do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "DELETE #destroy" do
    it "allows admins to delete the survey" do
      user = create(:admin)
      sign_in user
      survey = create(:survey, account: user.account)

      expect(Survey.count).to eq(1)

      delete :destroy, params: { id: survey.id }

      expect(Survey.count).to eq(0)
    end

    it "does not allow full access users to delete the survey" do
      user = create(:user)
      sign_in user
      survey = create(:survey, account: user.account)

      expect(Survey.count).to eq(1)

      delete :destroy, params: { id: survey.id }

      expect(Survey.count).to eq(1)
    end

    it "does not allow reporting only users to delete the survey" do
      user = create(:reporting_only_user)
      sign_in user
      survey = create(:survey, account: user.account)

      expect(Survey.count).to eq(1)

      delete :destroy, params: { id: survey.id }

      expect(Survey.count).to eq(1)
    end

    it "does not allow non logged-in users to delete the survey" do
      survey = create(:survey)

      expect(Survey.count).to eq(1)

      delete :destroy, params: { id: survey.id }

      expect(Survey.count).to eq(1)
    end
  end

  describe "PATCH #update" do
    it_behaves_like "survey update experiment" do
      let(:full_access_user) { create(:user) }
      let(:reporting_only_user) { create(:reporting_only_user) }
      let(:new_thank_you_message) { FFaker::Lorem.phrase }

      def make_the_call(user, survey)
        sign_in user

        patch :update, params: {
          id: survey.id,
          survey: {
            thank_you: new_thank_you_message,
            thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
          }
        }
      end

      def it_works(survey)
        expect(survey.reload.thank_you).to eq(new_thank_you_message)
      end

      def it_does_not_work(survey)
        expect(survey.reload.thank_you).not_to eq(new_thank_you_message)
      end
    end

    describe "question addition" do
      let(:user) { create(:user) }
      let(:survey) { create(:survey_without_question, account: user.account) }

      let(:update_params) do
        {
          id: survey.id,
          survey: {
            questions_attributes: {
              "0" => {
                question_type: "free_text_question",
                content: FFaker::Lorem.phrase,
                position: 0,
                diagram_properties_attributes: diagram_properties_attributes
              }
            },
            thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
          }
        }
      end

      before do
        sign_in user
        @old_number_of_questions = survey.questions.count
        patch :update, params: update_params
      end

      context "when the survey is not localized" do
        it "can add a question" do
          assert_response 200
          expect(survey.questions.count).to eq @old_number_of_questions + 1
        end
      end

      context "when the survey is localized" do
        let(:survey) do
          the_survey = create(:survey_without_question, account: user.account)
          the_survey.localize!
          the_survey.reload
        end

        it "does not add the question" do
          expect(survey.questions.count).to eq @old_number_of_questions
        end

        it "returns 400" do
          assert_response 400
        end

        it "returns an error message" do
          error_message = "Cannot create question for localized survey. Please use the localization (bulk) editor to add the question"

          expect(JSON.parse(response.body)["error"]).to eq error_message
        end
      end
    end

    describe "possible answer" do
      let(:user) { create(:user) }

      before do
        sign_in user

        @old_number_of_possible_answers = survey.reload.questions.first.possible_answers.count
      end

      describe "Localization" do
        before do
          question = survey.reload.questions.first
          question.possible_answers.new(content: FFaker::Lorem.sentence)

          patch :update, params: {
            id: survey.id,
            survey: {
              questions_attributes: question_payload([question]),
              thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
            }
          }
        end

        context "when the survey is not localized" do
          let(:survey) { create(:survey_with_one_question, account: user.account) }

          it "can add a possible answer" do
            assert_response 200
            expect(survey.possible_answers.count).to eq @old_number_of_possible_answers + 1
          end
        end

        context "when the survey is localized" do
          let(:survey) do
            the_survey = create(:survey_with_one_question, account: user.account)
            the_survey.localize!
            the_survey.reload
          end

          it "does not add the possible answer" do
            expect(survey.possible_answers.count).to eq @old_number_of_possible_answers
          end

          it "returns 400" do
            assert_response 400
          end

          it "returns an error message" do
            error_message = "Cannot create possible answer for localized survey. Please use the localization (bulk) editor to add the possible answer"

            expect(JSON.parse(response.body)["error"]).to eq error_message
          end
        end
      end

      context "with a possible answer next question for a multi choice question" do
        let(:survey) { create(:survey_with_one_multiple_question, account: user.account) }
        let(:multiple_choices_question) { survey.reload.questions.first }
        let(:last_possible_answer) { multiple_choices_question.possible_answers.sort_by_position.last }
        let(:next_question) { create(:question, survey: survey) }

        before do
          last_possible_answer.update(next_question: next_question)
        end

        context 'when adding a new possible answer' do
          before do
            multiple_choices_question.possible_answers.each { |possible_answer| possible_answer.increment(:position) }
            multiple_choices_question.possible_answers.new(content: FFaker::Lorem.sentence, position: 0)
          end

          it 'does not affect the possible answer next question' do
            patch :update, params: {
              id: survey.id,
              survey: {
                questions_attributes: question_payload([multiple_choices_question]),
                thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
              }
            }

            current_number_of_possible_answers = multiple_choices_question.reload.possible_answers.count
            expect(current_number_of_possible_answers).to eq @old_number_of_possible_answers + 1

            expect(last_possible_answer.reload.valid?).to be true
            expect(last_possible_answer.position).to eq current_number_of_possible_answers - 1
            expect(last_possible_answer.next_question).to eq next_question
          end
        end

        context 'when deleting a possible answer' do
          before do
            multiple_choices_question.possible_answers.each { |possible_answer| possible_answer.decrement(:position) }
            multiple_choices_question.possible_answers.first.mark_for_destruction
          end

          it 'does not affect the possible answer next question' do
            patch :update, params: {
              id: survey.id,
              survey: {
                questions_attributes: question_payload([multiple_choices_question]),
                thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
              }
            }

            current_number_of_possible_answers = multiple_choices_question.reload.possible_answers.count
            expect(current_number_of_possible_answers).to eq @old_number_of_possible_answers -1

            expect(last_possible_answer.reload.valid?).to be true
            expect(last_possible_answer.position).to eq current_number_of_possible_answers - 1
            expect(last_possible_answer.next_question).to eq next_question
          end
        end
      end

      def question_payload(questions)
        questions.each_with_index.with_object({}) do |(question, index), payload|
          payload[index.to_s] = {}
          payload[index.to_s][:id] = question.id if question.persisted?
          payload[index.to_s][:content] = question.content
          payload[index.to_s][:position] = question.position
          payload[index.to_s][:possible_answers_attributes] = possible_answer_payload(question.possible_answers)
          payload[index.to_s][:_destroy] = '1' if question.marked_for_destruction?
        end
      end

      def possible_answer_payload(possible_answers)
        possible_answers.each_with_index.with_object({}) do |(possible_answer, index), payload|
          payload[index.to_s] = {}
          payload[index.to_s][:id] = possible_answer.id if possible_answer.persisted?
          payload[index.to_s][:content] = possible_answer.content
          payload[index.to_s][:position] = possible_answer.position
          payload[index.to_s][:_destroy] = '1' if possible_answer.marked_for_destruction?
        end
      end
    end

    describe "locked survey changes" do
      %w(randomize_question_order display_all_questions).each do |column_name|
        describe "#{column_name} updates" do
          let(:user) { create(:user) }
          let(:original_value) { true }

          before do
            sign_in user

            update_params = {
              id: survey.id,
              survey: {
                column_name => !original_value,
                thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
              }
            }

            patch :update, params: update_params

            survey.reload
          end

          context "with a non-localized survey" do
            let(:survey) { create(:survey, account: user.account, column_name => original_value) }

            it "can change #{column_name}" do
              expect(survey.send(column_name)).to be !original_value
            end
          end

          context "with a localized survey" do
            let(:survey) { create(:localized_survey, account: user.account, column_name => original_value) }

            it "cannot change #{column_name}" do
              expect(survey.send(column_name)).to be original_value
            end

            it "returns 400" do
              assert_response 400
            end

            it "returns an error message" do
              error_message = "Cannot change #{column_name} for localized survey. Please use the localization (bulk) editor"

              expect(JSON.parse(response.body)["error"]).to eq error_message
            end
          end
        end
      end
    end

    describe "questions.randomize updates" do
      let(:user) { create(:user) }
      let(:original_value) { 0 }
      let(:new_value) { 1 }

      before do
        sign_in user

        @question = survey.questions[0]
        @question.update(randomize: 0)

        # Changing questions.randomize
        update_params = {
          id: survey.id,
          survey: {
            questions_attributes: {
              "0" => {
                id: @question.id,
                position: @question.position,
                randomize: new_value
              }
            },
            thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
          }
        }

        patch :update, params: update_params

        @question.reload
      end

      context "with a non-localized survey" do
        let(:survey) { create(:survey, account: user.account) }

        it "can change possible answer randomization" do
          expect(@question.randomize).to eq new_value
        end
      end

      context "with a localized survey" do
        let(:survey) { create(:localized_survey, account: user.account) }

        it "cannot change question position" do
          expect(@question.randomize).to eq original_value
        end

        it "returns 400" do
          assert_response 400
        end

        it "returns an error message" do
          error_message = "Cannot change possible answer randomization for localized survey. Please use the localization (bulk) editor"

          expect(JSON.parse(response.body)["error"]).to eq error_message
        end
      end
    end

    describe "possible_answers.position updates" do
      let(:user) { create(:user) }

      before do
        sign_in user

        possible_answers = survey.questions.first.possible_answers.sort_by_position

        @original_first_possible_answer = possible_answers[0]
        @original_second_possible_answer = possible_answers[1]

        # Swapping the positions of the first two possible answers
        update_params = {
          id: survey.id,
          survey: {
            questions_attributes: {
              "0" => {
                id: survey.questions.first.id,
                position: survey.questions.first.position,
                possible_answers_attributes: {
                  "0" => {
                    id: @original_first_possible_answer.id,
                    position: 1
                  },
                  "1" => {
                    id: @original_second_possible_answer.id,
                    position: 0
                  }
                }
              }
            },
            thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
          }
        }

        patch :update, params: update_params

        @original_first_possible_answer.reload
        @original_second_possible_answer.reload
      end

      context "with a non-localized survey" do
        let(:survey) { create(:survey, account: user.account) }

        it "can change possible_answer position" do
          expect(@original_first_possible_answer.position).to eq 1
          expect(@original_second_possible_answer.position).to eq 0
        end
      end

      context "with a localized survey" do
        let(:survey) { create(:localized_survey, account: user.account) }

        it "cannot change possible_answer position" do
          expect(@original_first_possible_answer.position).to eq 0
          expect(@original_second_possible_answer.position).to eq 1
        end

        it "returns 400" do
          assert_response 400
        end

        it "returns an error message" do
          error_message = "Cannot change possible answer position for localized survey."

          expect(JSON.parse(response.body)["error"]).to eq error_message
        end
      end
    end

    describe "questions.position updates" do
      let(:user) { create(:user) }

      before do
        sign_in user

        @original_first_question = survey.questions[0]
        @original_second_question = survey.questions[1]

        # Swapping the positions of the first two questions
        update_params = {
          id: survey.id,
          survey: {
            questions_attributes: {
              "0" => {
                id: @original_first_question.id,
                position: 1
              },
              "1" => {
                id: @original_second_question.id,
                position: 0
              }
            },
            thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
          }
        }

        patch :update, params: update_params

        @original_first_question.reload
        @original_second_question.reload
      end

      context "with a non-localized survey" do
        let(:survey) { create(:survey, account: user.account) }

        it "can change question position" do
          expect(@original_first_question.position).to eq 1
          expect(@original_second_question.position).to eq 0
        end
      end

      context "with a localized survey" do
        let(:survey) { create(:localized_survey, account: user.account) }

        it "cannot change question position" do
          expect(@original_first_question.position).to eq 0
          expect(@original_second_question.position).to eq 1
        end

        it "returns 400" do
          assert_response 400
        end

        it "returns an error message" do
          error_message = "Cannot change question position for localized survey."

          expect(JSON.parse(response.body)["error"]).to eq error_message
        end
      end
    end

    describe "routing" do
      let(:user) { create(:user) }
      let(:localized_survey) do
        the_survey = create(:survey_without_question, account: user.account)
        the_survey.localize!
        the_survey.reload
      end

      before do
        sign_in user
      end

      context "with a multiple choice question" do
        before do
          multiple_choices_question = create(:multiple_choices_question, survey: survey, position: 0)
          single_choice_question = create(:single_choice_question, survey: survey, position: 1)

          update_params = {
            id: survey.id,
            survey: {
              questions_attributes: {
                "0" => {
                  id: multiple_choices_question.id,
                  next_question_id: single_choice_question.id,
                  position: multiple_choices_question.position
                }
              },
              thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
            }
          }

          patch :update, params: update_params
        end

        context "when the survey is not localized" do
          let(:survey) { create(:survey_without_question, account: user.account) }

          it "can set multiple choice question routing" do
            assert_response 200
            expect(survey.questions.first.next_question_id).to eq survey.questions.last.id
          end
        end

        context "when the survey is localized" do
          let(:survey) { localized_survey }
          let(:error_message) { "Cannot change routing for localized survey." }

          it "cannot set multiple choice question routing" do
            assert_response 400
            expect(JSON.parse(response.body)["error"]).to eq error_message
            expect(survey.questions.first.next_question_id).to be_nil
          end
        end
      end

      context "with a free text question" do
        before do
          free_text_question = create(:free_text_question, survey: survey, position: 0)
          single_choice_question = create(:single_choice_question, survey: survey, position: 1)

          update_params = {
            id: survey.id,
            survey: {
              questions_attributes: {
                "0" => {
                  id: free_text_question.id,
                  free_text_next_question_id: single_choice_question.id,
                  position: free_text_question.position
                }
              },
              thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
            }
          }

          patch :update, params: update_params
        end

        context "when the survey is not localized" do
          let(:survey) { create(:survey_without_question, account: user.account) }

          it "can set free text question routing" do
            assert_response 200
            expect(survey.questions.first.free_text_next_question_id).to eq survey.questions.last.id
          end
        end

        context "when the survey is localized" do
          let(:survey) { localized_survey }
          let(:error_message) { "Cannot change routing for localized survey." }

          it "cannot set free text question routing" do
            assert_response 400
            expect(JSON.parse(response.body)["error"]).to eq error_message
            expect(survey.questions.first.free_text_next_question_id).to be_nil
          end
        end
      end

      context "with a single choice question possible answer" do
        before do
          create(:single_choice_question, survey: survey, position: 0)
          create(:single_choice_question, survey: survey, position: 1)

          @possible_answer_to_route = survey.questions.first.possible_answers.sort_by_position.first

          update_params = {
            id: survey.id,
            survey: {
              questions_attributes: {
                "0" => {
                  id: survey.questions.first.id,
                  position: survey.questions.first.position,
                  possible_answers_attributes: {
                    "0" => {
                      id: @possible_answer_to_route.id,
                      next_question_id: survey.questions.last.id,
                      position: @possible_answer_to_route.position
                    }
                  }
                }
              },
              thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
            }
          }

          patch :update, params: update_params
        end

        context "when the survey is not localized" do
          let(:survey) { create(:survey_without_question, account: user.account) }

          it "can set single choice possible answer routing" do
            assert_response 200
            expect(@possible_answer_to_route.reload.next_question_id).to eq survey.questions.last.id
          end
        end

        context "when the survey is localized" do
          let(:survey) { localized_survey }
          let(:error_message) { "Cannot change routing for localized survey." }

          it "cannot set single choice possible answer routing" do
            assert_response 400
            expect(JSON.parse(response.body)["error"]).to eq error_message
            expect(@possible_answer_to_route.reload.next_question_id).to be_nil
          end
        end
      end

      context "with the last possible answer of a multiple choice question" do
        before do
          multiple_choices_question = create(:multiple_choices_question, survey: survey, position: 0)
          @single_choice_question = create(:single_choice_question, survey: survey, position: 1)

          @possible_answer_to_route = survey.questions.first.possible_answers.sort_by_position.last

          update_params = {
            id: survey.id,
            survey: {
              questions_attributes: {
                "0" => {
                  id: multiple_choices_question.id,
                  position: multiple_choices_question.position,
                  possible_answers_attributes: {
                    # The question has two possible answers, the one at index 1 being the last
                    "1" => {
                      id: @possible_answer_to_route.id,
                      position: 1,
                      next_question_id: @single_choice_question.id
                    }
                  }
                }
              },
              thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
            }
          }

          patch :update, params: update_params
        end

        context "when the survey is not localized" do
          let(:survey) { create(:survey_without_question, account: user.account) }

          it "can set multiple choice question possible answer routing" do
            assert_response 200
            expect(@possible_answer_to_route.reload.next_question_id).to eq @single_choice_question.id
          end
        end

        context "when the survey is localized" do
          let(:survey) { localized_survey }
          let(:error_message) { "Cannot change routing for localized survey." }

          it "cannot set multiple choice question possible answer routing" do
            assert_response 400
            expect(JSON.parse(response.body)["error"]).to eq error_message
            expect(@possible_answer_to_route.reload.next_question_id).to be_nil
          end
        end
      end
    end

    it "stores question positions correctly when a question is added and another is deleted" do
      user = create(:user)
      sign_in user
      survey = create(:survey_with_one_question, account: user.account)
      survey.reload

      old_question_id = survey.questions.first.id

      update_params = {
        id: survey.id,
        survey: {
          questions_attributes: {
            "0" => {
              _destroy: 1,
              id: survey.questions.first.id
            },
            "1" => {
              question_type: "custom_content_question",
              position: 0,
              diagram_properties_attributes: diagram_properties_attributes
            }
          },
          thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
        }
      }

      patch :update, params: update_params

      expect(response).to have_http_status(:ok)

      survey.reload
      expect(survey.questions.count).to eq(1)
      expect(survey.questions.first.id).not_to eq(old_question_id)
      expect(survey.questions.first.position).to eq(0)
    end

    it "stores question positions correctly when a question is added in the first position" do
      user = create(:user)
      sign_in user
      survey = create(:survey_with_one_question, account: user.account)
      survey.reload

      old_question_id = survey.questions.first.id

      update_params = {
        id: survey.id,
        survey: {
          questions_attributes: {
            "0" => {
              id: survey.questions.first.id,
              position: 1
            },
            "1" => {
              question_type: "custom_content_question",
              position: 0,
              diagram_properties_attributes: diagram_properties_attributes
            }
          },
          thank_you_diagram_properties_attributes: build_thank_you_diagram_properties_attributes(survey, user)
        }
      }

      patch :update, params: update_params

      expect(response).to have_http_status(:ok)

      survey.reload
      expect(survey.questions.count).to eq(2)
      expect(survey.questions.last.id).to eq(old_question_id)
    end

    context "when the action is from localization editor" do
      let(:user) { create(:user) }
      let(:survey_locale_group) { create(:survey_locale_group, account: user.account) }
      let(:survey) { create(:survey, account: user.account, survey_locale_group: survey_locale_group) }

      before do
        sign_in user

        patch :localization_form_update, params: {
          id: survey.id,
          redirect_to_localization_editor: true,
          survey: {
            triggers_attributes: {
              "0" => {
                type_cd: "UrlTrigger",
                trigger_content: "sample/path"
              }
            }
          }
        }
      end

      it "updates survey" do
        expect(survey.triggers.count).to eq 1
        expect(survey.triggers.first.url).to eq("sample/path")
      end

      it "redirects to localization editor" do
        expect(response).to redirect_to localization_editor_path(survey_locale_group)
      end
    end

    describe "triggers" do
      let(:user) { create(:user) }
      let(:survey) { create(:survey, account: user.account) }

      context "when an existing trigger has its type changed" do
        before do
          @existing_trigger = create(:url_trigger, survey: survey, url: "pulseinsights")
          trigger_content = "https://www.pulseinsights.com"

          sign_in user

          update_params = {
            id: survey.id,
            survey: {
              triggers_attributes: {
                "0" => {
                  id: @existing_trigger.id,
                  type_cd: "UrlMatchesTrigger",
                  trigger_content: trigger_content
                }
              }
            }
          }

          patch :update, params: update_params
        end

        it "destroys the existing trigger" do
          expect(Trigger.find_by(id: @existing_trigger.id)).to be_nil
        end

        it "creates a new trigger with the new type" do
          trigger = survey.triggers.first

          expect(trigger.present?).to be true

          expect(trigger).to have_attributes(
            type_cd: "UrlMatchesTrigger",
            url_matches: "www.pulseinsights.com"
          )
        end
      end
    end
  end

  describe "PATCH #change_status" do
    let(:survey) { create(:survey, account: user.account) }

    before do
      sign_in user
      patch :change_status, params: { id: survey.id, status: 'paused' }
      survey.reload
    end

    context "when called by a full access user" do
      let(:user) { create(:user) }

      it "changes the status of the survey" do
        expect(survey.paused?).to be true
        expect_redirected_to_dashboard
      end
    end

    context "when called by a reporting only user" do
      let(:user) { create(:reporting_only_user) }

      it "changes the status of the survey" do
        expect(survey.live?).to be true
        expect_redirected_to_dashboard
      end
    end
  end

  describe "GET #localization_editor" do
    subject(:get_localization_editor) { get :localization_editor, params: { survey_locale_group_id: @base_survey.survey_locale_group_id } }

    it 'is inaccessible to reporting-only users' do
      user = create(:reporting_only_user)
      sign_in user
      @base_survey = create(:localized_survey, account: user.account)

      get_localization_editor

      expect_redirected_to_dashboard
    end

    it 'is accessible to full access users' do
      user = create(:user)
      sign_in user
      @base_survey = create(:localized_survey, account: user.account)

      get_localization_editor

      expect(response).to have_http_status(:ok)
    end

    it 'is inaccessible to users not belonging to account that created the survey' do
      user = create(:user)
      sign_in user
      @base_survey = create(:localized_survey, account: create(:account))

      get_localization_editor

      expect_redirected_to_dashboard
    end
  end

  # TODO: only allows name, goal, and status
  describe "POST #inline_edit" do
    let(:user) { create(:user) }
    let(:new_survey_name) { "new name" }
    let(:survey) { create(:survey, account: user.account) }

    before do
      sign_in user

      @old_survey_name = survey.name

      post :inline_edit, params: { id: survey.id, survey: { name: new_survey_name }}
      survey.reload
    end

    context "when the user is reporting only" do
      let(:user) { create(:reporting_only_user) }

      it "redirects to the dashboard" do
        assert_redirected_to dashboard_url
      end

      it "does not change the survey name" do
        expect(survey.name).to eq @old_survey_name
      end
    end

    context "when the user is full access" do
      it "returns 403" do
        assert_response 403
      end

      it "does not change the survey name" do
        expect(survey.name).to eq @old_survey_name
      end
    end

    context "when the user is an administrator" do
      let(:user) { create(:admin) }

      it "returns success" do
        assert_response 200
      end

      it "changes the survey name" do
        expect(survey.name).to eq new_survey_name
      end

      context "when the user belongs to a different account" do
        let(:survey) { create(:survey, account: create(:account)) }

        it "returns 404" do
          assert_response 404
        end

        it "does not change the survey name" do
          expect(survey.name).to eq @old_survey_name
        end
      end
    end
  end

  describe "POST #localization_duplicate" do
    it 'is not possible for reporting only users' do
      @user = create(:reporting_only_user)
      sign_in @user
      survey_locale_group = SurveyLocaleGroup.create(owner_record_id: @user.account.id, name: "Localization Testing")
      create(:survey, account: @user.account, survey_locale_group_id: survey_locale_group.id)

      expect(Survey.count).to eq(1)

      post :localization_duplicate, params: { survey_locale_group_id: survey_locale_group.id }

      expect_redirected_to_dashboard
      expect(Survey.count).to eq(1)
    end

    it 'is not possible for users not belonging to the account that created the survey' do
      user = create(:user)
      sign_in user
      base_survey = create(:localized_survey, account: create(:account))

      expect(Survey.count).to eq(1)

      post :localization_duplicate, params: { survey_locale_group_id: base_survey.survey_locale_group_id }

      expect_redirected_to_dashboard
      expect(Survey.count).to eq(1)
    end

    it 'is possible for full access users' do
      @user = create(:user)
      sign_in @user
      survey_locale_group = SurveyLocaleGroup.create(owner_record_id: @user.account.id, name: "Localization Testing")
      create(:survey, account: @user.account, survey_locale_group_id: survey_locale_group.id)

      post :localization_duplicate, params: { survey_locale_group_id: survey_locale_group.id }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(survey_locale_group.id))
    end

    it 'does not preserve language_code' do
      @user = create(:user)
      sign_in @user
      survey_locale_group = SurveyLocaleGroup.create(owner_record_id: @user.account.id, name: "Localization Testing")
      create(:survey, account: @user.account, survey_locale_group_id: survey_locale_group.id, language_code: 'en_us')

      post :localization_duplicate, params: { survey_locale_group_id: survey_locale_group.id }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(survey_locale_group.id))

      new_survey = Survey.last
      expect(new_survey.language_code).to be_nil
    end

    it "preserves LocaleGroup links" do
      @user = create(:user)
      sign_in @user
      base_survey = create(:localized_survey, account: @user.account)

      expect(Survey.count).to eq(1)
      post :localization_duplicate, params: { survey_locale_group_id: base_survey.survey_locale_group.id }
      expect(Survey.count).to eq(2)

      new_survey = Survey.last
      expect(new_survey).not_to eq(base_survey)

      expect(new_survey.survey_locale_group.id).to eq(base_survey.survey_locale_group.id)
      expect(new_survey.survey_locale_group.account.id).to eq(base_survey.survey_locale_group.account.id)

      # duplicate's questions have the same locale group as base's questions
      base_survey.questions.each_with_index do |question, i|
        new_question_locale_group = new_survey.questions[i].question_locale_group

        expect(new_question_locale_group.id).to eq(question.question_locale_group.id)
        expect(new_question_locale_group.survey_locale_group.id).to eq(question.question_locale_group.survey_locale_group.id)
      end

      # duplicate's possible_answers have the same locale group as base's possible answers
      base_survey.possible_answers.order(:created_at).each_with_index do |possible_answer, i|
        new_possible_answer_locale_group = new_survey.possible_answers.order(:created_at)[i].possible_answer_locale_group

        expect(new_possible_answer_locale_group.id).to eq(possible_answer.possible_answer_locale_group.id)
        expect(new_possible_answer_locale_group.question_locale_group.id).to eq(possible_answer.possible_answer_locale_group.question_locale_group.id)
      end
    end
  end

  describe "POST #localization_base_update" do
    it 'is not possible for reporting only users' do
      user = create(:reporting_only_user)
      sign_in user
      base_survey = create(:localized_survey, account: user.account)

      post :localization_base_update, params: {
        survey_locale_group_id: base_survey.survey_locale_group_id,
        survey: {
          desktop_enabled: true
        }
      }

      expect_redirected_to_dashboard
    end

    it 'is not possible for users not belonging to the account that owns the SurveyLocaleGroup' do
      user = create(:user)
      sign_in user
      owned_survey = create(:localized_survey, account: user.account)
      unowned_survey = create(:localized_survey, account: create(:account))

      post :localization_base_update, params: {
        survey_locale_group_id: unowned_survey.survey_locale_group_id,
        survey: {
          desktop_enabled: true
        }
      }

      expect_redirected_to_dashboard
    end

    it 'is possible for full access users' do
      user = create(:user)
      sign_in user
      base_survey = create(:localized_survey, account: user.account)

      post :localization_base_update, params: {
        survey_locale_group_id: base_survey.survey_locale_group.id,
        survey: {
          desktop_enabled: true
        }
      }

      it_succeeds_with_json_response

      expect(json_response).to eq({})
    end

    it 'applies change to all surveys in the same SurveyLocaleGroup' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)
      base_survey.reload

      add_variety_of_language_surveys(base_survey)

      untouched_survey = create(:localized_survey, account: user.account)

      post :localization_base_update, params: {
        survey_locale_group_id: base_survey.survey_locale_group.id,
        survey: {
          status: "paused"
        }
      }

      it_succeeds_with_json_response

      expect(base_survey.survey_locale_group.surveys.pluck(:status).uniq).to eq(["paused"])
      expect(untouched_survey.status).not_to eq("paused")
    end

    it 'updates live_at appropriately' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      add_variety_of_language_surveys(base_survey)

      Survey.update_all(status: :live, live_at: Time.now.utc - 1.minute)

      paused_survey = Survey.last
      paused_survey.update(status: 2)

      live_at_threshold = Time.now.utc - 30.seconds

      post :localization_base_update, params: {
        survey_locale_group_id: base_survey.survey_locale_group.id,
        survey: {
          status: "live"
        }
      }

      it_succeeds_with_json_response

      surveys = base_survey.survey_locale_group.surveys.reload

      paused_survey.reload

      expect(surveys.pluck(:status).uniq).to eq(["live"])
      all_surveys_except_paused = surveys.reject { |survey| survey.id == paused_survey.id }

      expect(all_surveys_except_paused.all? { |survey| survey.live_at < live_at_threshold }).to be true
      expect(paused_survey.live_at > live_at_threshold).to be true
    end
  end

  describe "POST #localization_content_update" do
    it 'is not possible for reporting only users' do
      user = create(:reporting_only_user)
      sign_in user
      base_survey = create(:localized_survey, account: user.account)

      post :localization_content_update, params: {
        survey_locale_group_id: base_survey.survey_locale_group_id,
        survey_id: base_survey.id,
        survey: {
          invitation: "Please send us feedback"
        }
      }

      expect_redirected_to_dashboard
    end

    it 'is not possible for users not belonging to the account that owns the SurveyLocaleGroup' do
      user = create(:user)
      sign_in user
      owned_survey = create(:localized_survey, account: user.account)
      unowned_survey = create(:localized_survey, account: create(:account))

      post :localization_content_update, params: {
        survey_locale_group_id: unowned_survey.survey_locale_group_id,
        survey_id: owned_survey.id,
        survey: {
          invitation: "Please send us feedback"
        }
      }

      expect_redirected_to_dashboard
    end

    it 'is not possible for users not belonging to the account that owns the Survey' do
      user = create(:user)
      sign_in user
      owned_survey = create(:localized_survey, account: user.account)

      unowned_survey = create(:localized_survey, account: create(:account))

      post :localization_content_update, params: {
        survey_locale_group_id: owned_survey.survey_locale_group_id,
        survey_id: unowned_survey.id,
        survey: {
          invitation: "Please send us feedback"
        }
      }

      expect_redirected_to_dashboard
    end

    describe "for valid use cases" do
      before do
        @user = create(:user)
        sign_in @user
        @base_survey = create(:localized_survey, account: @user.account)
        @base_survey.reload
      end

      it 'is possible for full access users' do
        post :localization_content_update, params: {
          survey_locale_group_id: @base_survey.survey_locale_group.id,
          survey_id: @base_survey.id,
          survey: {
            invitation: "Please send us feedback"
          }
        }

        it_succeeds_with_json_response
        expect(json_response).to eq({})
      end

      it 'updates question content in all surveys having the same language_code' do
        add_variety_of_language_surveys(@base_survey)

        new_content = "New question content"
        base_question = @base_survey.questions.last
        question_locale_group_id = base_question.question_locale_group_id

        post :localization_content_update, params: {
          survey_locale_group_id: @base_survey.survey_locale_group.id,
          survey_id: @base_survey.id,
          survey: {
            questions_attributes: {
              id: base_question.id,
              content: new_content
            }
          }
        }

        english_surveys, non_english_surveys = @base_survey.survey_locale_group.surveys.partition { |survey| survey.language_code == "en_gb" }

        # en_gb question content was updated
        english_surveys.map(&:questions).flatten.each do |question|
          if question.question_locale_group_id == question_locale_group_id
            expect(question.content).to eq(new_content)
            expect(question.audits.changes_attribute_to(:content, new_content)).not_to be_empty
          else
            expect(question.content).not_to eq(new_content)
          end
        end

        # no other records were updated
        non_english_surveys.map(&:questions).flatten.each do |non_english_survey_question|
          expect(non_english_survey_question.content).not_to eq(new_content)
        end

        it_succeeds_with_json_response
      end

      it 'updates possible answer content in all surveys having the same language_code' do
        add_variety_of_language_surveys(@base_survey)

        new_content = "New possible answer content"
        base_question = @base_survey.questions.last
        base_possible_answer = base_question.possible_answers.first
        possible_answer_locale_group_id = base_possible_answer.possible_answer_locale_group_id

        post :localization_content_update, params: {
          survey_locale_group_id: @base_survey.survey_locale_group.id,
          survey_id: @base_survey.id,
          survey: {
            questions_attributes: {
              id: base_question.id,
              possible_answers_attributes: {
                id: base_possible_answer.id,
                content: new_content
              }
            }
          }
        }

        english_surveys, non_english_surveys = @base_survey.survey_locale_group.surveys.partition { |survey| survey.language_code == "en_gb" }

        # en_gb possible answer content was updated
        english_surveys.map(&:possible_answers).flatten.each do |possible_answer|
          if possible_answer.possible_answer_locale_group_id == possible_answer_locale_group_id
            expect(possible_answer.content).to eq(new_content)
            expect(possible_answer.audits.changes_attribute_to(:content, new_content)).not_to be_empty
          else
            expect(possible_answer.content).not_to eq(new_content)
          end
        end

        # no other records were updated
        non_english_surveys.map(&:possible_answers).flatten.each do |possible_answer|
          expect(possible_answer.content).not_to eq(new_content)
        end

        it_succeeds_with_json_response
      end

      it 'updates survey content in all surveys having the same language_code' do
        add_variety_of_language_surveys(@base_survey)

        new_content = "New invitation content"

        post :localization_content_update, params: {
          survey_locale_group_id: @base_survey.survey_locale_group.id,
          survey_id: @base_survey.id,
          survey: {
            invitation: new_content
          }
        }

        english_surveys, non_english_surveys = @base_survey.survey_locale_group.surveys.partition { |survey| survey.language_code == "en_gb" }

        english_surveys.each do |english_survey|
          expect(english_survey.invitation).to eq(new_content)
          expect(english_survey.audits.changes_attribute_to(:invitation, new_content)).not_to be_empty
        end

        non_english_surveys.each do |non_english_survey|
          expect(non_english_survey.invitation).not_to eq(new_content)
        end

        it_succeeds_with_json_response
      end
    end
  end

  describe "POST #localization_update" do
    it 'is not possible for reporting only users' do
      user = create(:reporting_only_user)
      sign_in user
      base_survey = create(:localized_survey, account: user.account)

      post :localization_update, params: {
        survey_locale_group_id: base_survey.survey_locale_group_id,
        survey_id: base_survey.id,
        survey: {
          meaningless: :placeholder
        }
      }

      expect_redirected_to_dashboard
    end

    it 'is not possible for users not belonging to the account that owns the SurveyLocaleGroup' do
      user = create(:user)
      sign_in user
      owned_survey = create(:localized_survey, account: user.account)
      unowned_survey = create(:localized_survey, account: create(:account))

      post :localization_update, params: {
        survey_locale_group_id: unowned_survey.survey_locale_group_id,
        survey_id: owned_survey.id,
        survey: {
          meaningless: :placeholder
        }
      }

      expect_redirected_to_dashboard
    end

    it 'is not possible for users not belonging to the account that owns the Survey' do
      user = create(:user)
      sign_in user
      owned_survey = create(:localized_survey, account: user.account)

      unowned_survey = create(:localized_survey, account: create(:account))

      post :localization_update, params: {
        survey_locale_group_id: owned_survey.survey_locale_group_id,
        survey_id: unowned_survey.id,
        survey: {
          meaningless: :placeholder
        }
      }

      expect_redirected_to_dashboard
    end

    it 'is possible for full access users' do
      user = create(:user)
      sign_in user
      base_survey = create(:localized_survey, account: user.account)

      post :localization_update, params: {
        survey_locale_group_id: base_survey.survey_locale_group.id,
        survey_id: base_survey.id,
        survey: { meaningless: :placeholder }
      }

      it_succeeds_with_json_response
      expect(json_response).to eq({})
    end

    it "can update thank_you" do
      user = create(:user)
      sign_in user
      base_survey = create(:localized_survey, account: user.account)
      new_thank_you = "That's all, folks!"

      post :localization_update, params: {
        survey_locale_group_id: base_survey.survey_locale_group.id,
        survey_id: base_survey.id,
        survey: { thank_you: new_thank_you }
      }

      it_succeeds_with_json_response
      base_survey.reload
      expect(base_survey.thank_you).to eq(new_thank_you)
    end

    describe "survey name" do
      let(:user) { create(:user) }

      before do
        sign_in user
        @survey = create(:localized_survey, account: user.account)
        @old_survey_name = @survey.name
        @new_survey_name = "A revised survey"

        post :localization_update, params: {
          survey_locale_group_id: @survey.survey_locale_group.id,
          survey_id: @survey.id,
          survey: { name: @new_survey_name }
        }

        @survey.reload
      end

      context "when the user is full access" do
        it "returns 403" do
          assert_response 403
        end

        it "does not change the survey name" do
          expect(@survey.name).to eq @old_survey_name
        end
      end

      context "when the user is an administrator" do
        let(:user) { create(:admin) }

        it "returns success" do
          assert_response 200
        end

        it "changes the survey name" do
          expect(@survey.name).to eq @new_survey_name
        end
      end
    end

    context "when a new possible answer is added to a multiple choice question" do
      before do
        user = create(:user)
        sign_in user

        base_survey = create(:survey_with_one_multiple_question, account: user.account)
        multiple_choice_question = base_survey.questions.reload.first

        question_to_route_to = create(:single_choice_question, survey: base_survey)
        base_survey.questions << question_to_route_to

        multiple_choice_question.possible_answers.last.update(next_question_id: question_to_route_to.id)

        base_survey.localize!

        @duplicate_survey = base_survey.duplicate
        @duplicate_survey.save
        @duplicate_survey.reattach_plumbing_lines(base_survey)

        possible_answer_locale_group = create(
          :possible_answer_locale_group,
          owner_record_id: multiple_choice_question.question_locale_group_id
        )

        post :localization_update, params: {
          survey_locale_group_id: @duplicate_survey.survey_locale_group_id,
          survey_id: @duplicate_survey.id,
          survey: {
            questions_attributes: {
              "0" => {
                id: @duplicate_survey.questions.first.id,
                possible_answers_attributes: {
                  "0" => {
                    possible_answer_locale_group_id: possible_answer_locale_group.id,
                    content: "yo"
                  }
                }
              }
            }
          }
        }
      end

      it "removes the routing from the second last possible answer" do
        multiple_choice_question = @duplicate_survey.questions.first
        next_question_id = multiple_choice_question.possible_answers.order(:position).second_to_last.next_question_id

        expect(next_question_id).to be_nil
      end
    end

    # rubocop:disable RSpec/ExampleLength
    # There's a lot to test
    it 'applies possible answer routing to new possible answers in non-base survey' do
      user = create(:user)
      sign_in user
      base_survey = create(:localized_survey, account: user.account)
      base_survey.reload

      post :duplicate, params: { id: base_survey.id }

      new_survey = Survey.order(:created_at).last

      possible_answer_locale_group = create(
        :possible_answer_locale_group,
        owner_record_id: base_survey.questions.first.question_locale_group_id
      )

      create(
        :possible_answer,
        question: base_survey.questions.first,
        possible_answer_locale_group_id: possible_answer_locale_group.id,
        next_question_id: base_survey.questions.last.id
      )
      base_survey.questions.reload

      post :localization_update, params: {
        survey_locale_group_id: base_survey.survey_locale_group.id,
        survey_id: new_survey.id,
        survey: {
          questions_attributes: {
            "0" => {
              id: new_survey.questions.first.id,
              possible_answers_attributes: {
                "0" => {
                  possible_answer_locale_group_id: possible_answer_locale_group.id,
                  content: "yo"
                }
              }
            }
          }
        }
      }

      new_survey.questions.reload
      expect(new_survey.questions.first.possible_answers.last.next_question_id).to eq(new_survey.questions.last.id)
    end
  end

  describe "POST #duplicate" do
    it 'does not be possible for reporting only users' do
      @user = create(:reporting_only_user)
      sign_in @user
      @survey = create(:survey, account: @user.account)

      expect(Survey.count).to eq(1)

      post :duplicate, params: { id: @survey.id }

      expect(Survey.count).to eq(1)
    end

    it 'is possible for full access users' do
      @user = create(:user)
      sign_in @user
      @survey = create(:survey, account: @user.account)

      expect(Survey.count).to eq(1)

      post :duplicate, params: { id: @survey.id }

      expect(Survey.count).to eq(2)
    end

    it "creates a new survey with 'Copy' appended to the name" do
      @user = create(:user)
      sign_in @user
      @survey = create(:survey, account: @user.account)

      expect(Survey.count).to eq(1)

      post :duplicate, params: { id: @survey.id }

      expect(Survey.count).to eq(2)

      copied_survey = Survey.last

      expect(copied_survey.name).to eq("#{@survey.name} Copy")
    end

    it "creates a new survey with 'Draft' as status" do
      @user = create(:user)
      sign_in @user
      @survey = create(:survey, account: @user.account)

      expect(Survey.count).to eq(1)

      post :duplicate, params: { id: @survey.id }

      expect(Survey.count).to eq(2)

      copied_survey = Survey.last

      expect(@survey.status).to eq('live')
      expect(copied_survey.status).to eq('draft')
    end

    it 'copies all survey information' do
      @user = create(:user)
      sign_in @user
      @survey = create(:survey, account: @user.account, stop_showing_without_answer: true, mobile_enabled: false, goal: 100_000)

      expect(Survey.count).to eq(1)

      post :duplicate, params: { id: @survey.id }

      expect(Survey.count).to eq(2)

      copied_survey = Survey.last

      expect(copied_survey.stop_showing_without_answer).to be(true)
      expect(copied_survey.mobile_enabled).to be(false)
      expect(copied_survey.goal).to eq("100,000")
    end

    it 'copies questions' do
      @user = create(:user)
      sign_in @user
      @survey = create(:survey, account: @user.account)

      expect(Survey.count).to eq(1)

      post :duplicate, params: { id: @survey.id }

      expect(Survey.count).to eq(2)

      copied_survey = Survey.last

      expect(@survey.questions.count).to eq 2
      expect(copied_survey.questions.count).to eq 2
    end

    it 'copies possible_answers' do
      @user = create(:user)
      sign_in @user
      @survey = create(:survey, account: @user.account)

      expect(Survey.count).to eq(1)

      post :duplicate, params: { id: @survey.id }

      expect(Survey.count).to eq(2)

      copied_survey = Survey.last

      expect(@survey.reload.questions.map(&:possible_answers).count).to eq 2
      expect(copied_survey.questions.map(&:possible_answers).count).to eq 2
    end

    it 'copies triggers' do
      @user = create(:user)
      sign_in @user
      @survey = create(:survey, account: @user.account)

      @survey.triggers.create(type_cd: 'UrlTrigger', url: '/abc')
      @survey.suppressers.create(type_cd: 'RegexpTrigger', regexp: '^localhost:3000/$')

      expect(Survey.count).to eq(1)

      post :duplicate, params: { id: @survey.id }

      expect(Survey.count).to eq(2)

      copied_survey = Survey.last

      expect(Trigger.where(survey_id: @survey.id).count).to eq 2
      expect(Trigger.where(survey_id: copied_survey.id).count).to eq 2
    end

    it 'copies next_question_id' do
      user = create(:user)
      sign_in user
      survey = create(:survey, account: user.account)
      survey.reload

      routed_possible_answer = survey.questions.first.possible_answers.sort_by_position.first
      routed_possible_answer.update(next_question_id: survey.questions.last.id)

      # reverse possible answer order
      survey.questions.each do |question|
        possible_answers = question.possible_answers.sort_by_position
        possible_answers.each_with_index do |possible_answer, i|
          possible_answer.update(position: possible_answers.count - i - 1)
        end
      end

      post :duplicate, params: { id: survey.id }

      copied_survey = Survey.last.reload

      expect(copied_survey.questions.first.possible_answers.sort_by_position.last.next_question_id).to eq(copied_survey.questions.last.id)
    end

    it 'can accommodate duplicate question.content-possible_answer.content pairs' do
      user = create(:user)
      sign_in user
      survey = create(:survey_without_question, account: user.account)
      survey.reload

      question1 = create(:question_without_possible_answers, survey: survey, question_type: :single_choice_question, content: "How are you?", position: 1)
      question2 = create(:question_without_possible_answers, survey: survey, question_type: :single_choice_question, content: "How are you?", position: 2)
      question3 = create(:question_without_possible_answers, survey: survey, question_type: :single_choice_question, content: "Where are you?", position: 3)
      question4 = create(:question_without_possible_answers, survey: survey, question_type: :single_choice_question, content: "When are you?", position: 4)

      create(:possible_answer, content: "Good", question: question1, next_question_id: question3.id)
      create(:possible_answer, content: "Great", question: question1, next_question_id: question3.id)

      create(:possible_answer, content: "Good", question: question2, next_question_id: question4.id)
      create(:possible_answer, content: "Great", question: question2, next_question_id: question4.id)

      create(:possible_answer, content: "A", question: question3)
      create(:possible_answer, content: "B", question: question4)

      expect(question1.possible_answers[0].next_question_id).to eq question3.id
      expect(question1.possible_answers[1].next_question_id).to eq question3.id

      expect(question2.possible_answers[0].next_question_id).to eq question4.id
      expect(question2.possible_answers[1].next_question_id).to eq question4.id

      survey.reload

      post :duplicate, params: { id: survey.id }

      copied_survey = Survey.last.reload

      expect(question1.possible_answers[0].next_question_id).to eq question3.id
      expect(question1.possible_answers[1].next_question_id).to eq question3.id

      expect(question2.possible_answers[0].next_question_id).to eq question4.id
      expect(question2.possible_answers[1].next_question_id).to eq question4.id

      expect(copied_survey.questions[0].possible_answers[0].next_question_id).to eq copied_survey.questions[2].id
      expect(copied_survey.questions[0].possible_answers[1].next_question_id).to eq copied_survey.questions[2].id

      expect(copied_survey.questions[1].possible_answers[0].next_question_id).to eq copied_survey.questions[3].id
      expect(copied_survey.questions[1].possible_answers[1].next_question_id).to eq copied_survey.questions[3].id
    end

    it 'can accommodate duplicate free_text question.content-question.question_type pairs' do
      user = create(:user)
      sign_in user
      survey = create(:survey_without_question, account: user.account)
      survey.reload

      question1 = create(:question_without_possible_answers, survey: survey, question_type: :free_text_question, content: "How are you?", position: 1)
      question2 = create(:question_without_possible_answers, survey: survey, question_type: :free_text_question, content: "How are you?", position: 2)
      question3 = create(:question_without_possible_answers, survey: survey, question_type: :single_choice_question, content: "Where are you?", position: 3)
      question4 = create(:question_without_possible_answers, survey: survey, question_type: :single_choice_question, content: "When are you?", position: 4)

      question1.update(free_text_next_question_id: question3.id)
      question2.update(free_text_next_question_id: question4.id)

      survey.reload

      post :duplicate, params: { id: survey.id }

      copied_survey = Survey.last.reload

      expect(question1.free_text_next_question_id).to eq question3.id
      expect(question2.free_text_next_question_id).to eq question4.id

      expect(copied_survey.questions[0].free_text_next_question_id).to eq copied_survey.questions[2].id
      expect(copied_survey.questions[0].free_text_next_question_id).to eq copied_survey.questions[2].id

      expect(copied_survey.questions[1].free_text_next_question_id).to eq copied_survey.questions[3].id
      expect(copied_survey.questions[1].free_text_next_question_id).to eq copied_survey.questions[3].id
    end

    it 'can accommodate duplicate multiple_choices question.content-question.question_type pairs' do
      user = create(:user)
      sign_in user
      survey = create(:survey_without_question, account: user.account)
      survey.reload

      question1 = create(:question_without_possible_answers, survey: survey, question_type: :multiple_choices_question, content: "How are you?", position: 1)
      question2 = create(:question_without_possible_answers, survey: survey, question_type: :multiple_choices_question, content: "How are you?", position: 2)
      question3 = create(:question_without_possible_answers, survey: survey, question_type: :single_choice_question, content: "Where are you?", position: 3)
      question4 = create(:question_without_possible_answers, survey: survey, question_type: :single_choice_question, content: "When are you?", position: 4)

      question1.update(next_question_id: question3.id)
      question2.update(next_question_id: question4.id)

      survey.reload

      post :duplicate, params: { id: survey.id }

      copied_survey = Survey.last.reload

      expect(question1.next_question_id).to eq question3.id
      expect(question2.next_question_id).to eq question4.id

      expect(copied_survey.questions[0].next_question_id).to eq copied_survey.questions[2].id
      expect(copied_survey.questions[0].next_question_id).to eq copied_survey.questions[2].id

      expect(copied_survey.questions[1].next_question_id).to eq copied_survey.questions[3].id
      expect(copied_survey.questions[1].next_question_id).to eq copied_survey.questions[3].id
    end

    it 'works via XHR' do
      @user = create(:user)
      sign_in @user
      @survey = create(:survey, account: @user.account)

      expect(Survey.count).to eq(1)

      post :duplicate, params: { id: @survey.id }, xhr: true

      expect(Survey.count).to eq(2)
    end
  end

  describe "GET #report" do
    before do
      @user = create(:user)
      @survey = create(:survey, account: @user.account)
    end

    it "does not work when the user is not signed in" do
      get :report, params: { id: @survey.id }
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to sign_in_path
    end

    it "works when the user is signed in" do
      sign_in @user
      get :report, params: { id: @survey.id }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #localization_report_stats" do
    let(:account) { create(:account, viewed_impressions_enabled_at: FFaker::Time.datetime) }
    let(:user) { create(:user, account: account) }
    let(:localized_survey) { create(:localized_survey, account: account) }

    context "when the user is not signed in" do
      before do
        get :localization_report_stats, params: { survey_locale_group_id: localized_survey.survey_locale_group_id }
      end

      it "redirects them to the signin page" do
        assert_redirected_to sign_in_path
      end
    end

    context "when the user is signed in" do
      before do
        sign_in user

        get :localization_report_stats, params: { survey_locale_group_id: localized_survey.survey_locale_group_id }
      end

      context "when the user is a report-only user" do
        let(:user) { create(:reporting_only_user, account: account) }

        it "loads the page" do
          assert_response 200
        end
      end

      context "when the user is a full access user" do
        let(:user) { create(:user, account: account) }

        it "loads the page" do
          assert_response 200
        end

        context "when the user does not belong to the account" do
          let(:localized_survey) { create(:localized_survey, account: create(:account)) }

          it "redirects them to the dashboard" do
            assert_redirected_to dashboard_path
          end
        end
      end

      context "when the user is an admin" do
        let(:user) { create(:admin, account: account) }

        it "loads the page" do
          assert_response 200
        end
      end
    end

    describe 'cache utilization' do
      let(:date_range) { 1.day.ago..Time.current }
      let(:device_type) { 'desktop' }

      before do
        sign_in user

        # Distinguishing between the number of impressions vs. the counts in cache records with additional impressions created in the
        # last 10 minutes, as the cache worker runs every 10 minute, making it realistic for the numbers to differ within that interval
        created_at = rand(date_range.first..10.minutes.ago)
        10.times { create(:submission, survey: localized_survey, device_type: device_type, created_at: created_at, viewed_at: created_at) }
        create(:survey_submission_cache, survey: localized_survey, impression_count: 10, viewed_impression_count: 10, applies_to_date: created_at)

        10.times do |n|
          created_at_after_caching = created_at + n.minutes
          create(:submission, survey: localized_survey, device_type: device_type, created_at: created_at_after_caching, viewed_at: created_at_after_caching)
        end
      end

      context 'when filters are empty' do
        before do
          get :localization_report_stats, params: { survey_locale_group_id: localized_survey.survey_locale_group_id }
        end

        it 'utilizes caches' do
          expect(JSON.parse(response.body)['impression_count'].to_i).to eq 10
        end
      end

      context 'when filters only contain date_range' do
        before do
          get :localization_report_stats, params: { survey_locale_group_id: localized_survey.survey_locale_group_id, date_range: date_range }
        end

        it 'utilizes caches' do
          expect(JSON.parse(response.body)['impression_count'].to_i).to eq 10
        end
      end

      context 'when filters contain something other than date_range' do
        before do
          get :localization_report_stats, params: { survey_locale_group_id: localized_survey.survey_locale_group_id, device_types: device_type }
        end

        it 'does not utilize caches' do
          expect(JSON.parse(response.body)['impression_count'].to_i).to eq 20
        end
      end
    end
  end

  describe "GET #localization_report" do
    let(:user) { create(:user) }
    let(:localized_survey) { create(:localized_survey, account: user.account) }

    context "when the user is not signed in" do
      before do
        get :localization_report, params: { survey_locale_group_id: localized_survey.survey_locale_group_id }
      end

      it "redirects them to the signin page" do
        assert_redirected_to sign_in_path
      end
    end

    context "when the user is signed in" do
      before do
        sign_in user

        get :localization_report, params: { survey_locale_group_id: localized_survey.survey_locale_group_id }
      end

      context "when the user is a report-only user" do
        let(:user) { create(:reporting_only_user) }

        it "loads the page" do
          assert_response 200
        end
      end

      context "when the user is a full access user" do
        let(:user) { create(:user) }

        it "loads the page" do
          assert_response 200
        end

        context "when the user does not belong to the account" do
          let(:localized_survey) { create(:localized_survey, account: create(:account)) }

          it "redirects them to the dashboard" do
            assert_redirected_to dashboard_path
          end
        end
      end

      context "when the user is an admin" do
        let(:user) { create(:admin) }

        it "loads the page" do
          assert_response 200
        end
      end
    end
  end

  describe "report AJAX calls" do
    let(:viewed_impressions_enabled_at) { FFaker::Time.between(Time.new(2014, 10), Time.current) }

    before do
      account = create(:account, viewed_impressions_enabled_at: viewed_impressions_enabled_at)
      @user = create(:user, account: account)
      sign_in @user

      @survey = create(:survey, account: account)

      @question = @survey.reload.questions.first

      @possible_answer = @question.reload.possible_answers.sort_by_position.first
    end

    describe "for a non-localized survey" do
      describe 'POST #background_report_stats' do
        it_behaves_like "filter sharing" do
          let(:for_endpoint) { true }

          def it_filters(filters)
            it_returns_accurate_report_stats(filters)
          end

          def make_records(filter_attribute = nil, attribute_value = nil)
            make_non_localized_answers_for_possible_answer(@survey, @possible_answer, filter_attribute, attribute_value)
          end
        end

        describe 'cache utilization' do
          let(:account) { create(:account) }
          let(:user) { create(:user, account: account) }
          let(:survey) { create(:survey, account: account) }

          let(:date_range) { 1.day.ago..Time.current }
          let(:device_type) { 'desktop' }

          before do
            sign_in user

            # Distinguishing between the number of impressions vs. the counts in cache records with additional impressions created in the
            # last 10 minutes, as the cache worker runs every 10 minute, making it realistic for the numbers to differ within that interval
            created_at = rand(date_range.first..10.minutes.ago)
            10.times { create(:submission, survey: survey, device_type: device_type, created_at: created_at) }
            create(:survey_submission_cache, survey: survey, impression_count: 10, applies_to_date: created_at)

            10.times { |n| create(:submission, survey: survey, device_type: device_type, created_at: created_at + n.minutes) }
          end

          context 'when filters are empty' do
            before do
              get :background_report_stats, params: { id: survey.id }
            end

            it 'utilizes caches' do
              expect(JSON.parse(response.body)['impression_count'].to_i).to eq 10
            end
          end

          context 'when filters only contain date_range' do
            before do
              get :background_report_stats, params: { id: survey.id, date_range: date_range }
            end

            it 'utilizes caches' do
              expect(JSON.parse(response.body)['impression_count'].to_i).to eq 10
            end
          end

          context 'when filters contain something other than date_range' do
            before do
              get :background_report_stats, params: { id: survey.id, device_types: device_type }
            end

            it 'does not utilize caches' do
              expect(JSON.parse(response.body)['impression_count'].to_i).to eq 20
            end
          end
        end
      end

      describe 'POST #background_report_metrics' do
        it_behaves_like "filter sharing" do
          let(:for_endpoint) { true }

          def it_filters(filters)
            it_returns_accurate_report_metrics(filters)
          end

          def make_records(filter_attribute = nil, attribute_value = nil)
            make_non_localized_answers_for_possible_answer(@survey, @possible_answer, filter_attribute, attribute_value)
          end
        end

        context "when there are no filters applied" do
          before do
            create(:submission, survey: @survey, created_at: 1.day.ago)

            submission = create(:submission, survey: @survey, created_at: 1.day.ago, viewed_at: 1.day.ago, answers_count: 1)
            create(:answer, submission: submission, possible_answer: @possible_answer, created_at: submission.created_at)

            @survey.submission_caches.create(applies_to_date: submission.created_at.to_date, submission_count: 1,
                                             viewed_impression_count: 1, impression_count: 2)
          end

          it "returns accurate metrics" do
            it_returns_accurate_report_metrics({})
          end
        end

        context 'when impressions are spread over days' do
          let(:date_range) { 3.days.ago.to_date..Date.today }
          let(:date_count) { (date_range.last - date_range.first).to_i + 1 }

          before do
            date_range.each do |date|
              10.times { create(:submission, survey: @survey, created_at: date) }
              8.times { create(:submission, survey: @survey, created_at: date, viewed_at: date) }
              6.times do
                submission = create(:submission, survey: @survey, created_at: date, viewed_at: date, answers_count: 1)
                create(:answer, submission: submission, question: @question, possible_answer: @possible_answer)
              end
            end
          end

          it 'sorts dates in ascending order' do
            get :background_report_metrics, params: { id: @survey.id, date_range: date_range }

            %w(impression_sum submission_sum rate).each do |metric_key|
              timestamps = json_response[metric_key].map(&:first)
              expect(timestamps.count).to eq date_count
              expect(timestamps).to eq timestamps.sort
            end
          end
        end
      end
    end

    describe "for a localized survey" do
      before do
        @survey.localize!

        @survey_locale_group = @survey.survey_locale_group

        @duplicate_survey1 = @survey.duplicate
        @duplicate_survey1.save
        @duplicate_survey1.add_to_localization_group(@survey_locale_group.id, "en-ca")

        @duplicate_survey2 = @survey.duplicate
        @duplicate_survey2.save
        @duplicate_survey2.add_to_localization_group(@survey_locale_group.id, "fr-ca")
      end

      def make_localized_answer(survey, submission_extras: {})
        submission = create(:submission, survey_id: survey.id, created_at: survey.account.viewed_impressions_enabled_at,
                            viewed_at: FFaker::Time.datetime, **submission_extras)
        question = survey.questions.first
        possible_answer = question.possible_answers.sort_by_position.first
        create(:answer, question_id: question.id, submission_id: submission.id, possible_answer_id: possible_answer.id)
      end

      def make_localized_records(filter_attribute = nil, attribute_value = nil)
        make_localized_answer(@survey) and return if filter_attribute.nil?

        case filter_attribute
        when :pageview_count, :visit_count, :url, :device_type, :created_at
          make_localized_answer(@survey, submission_extras: { filter_attribute => attribute_value })
        when :possible_answer_id
          make_possible_answer_filter_records(@survey, attribute_value)
        else
          raise "Unrecognized data type #{filter_attribute}"
        end
      end

      describe 'POST #background_report_stats' do
        it_behaves_like "filter sharing" do
          let(:for_endpoint) { true }

          def it_filters(filters)
            it_returns_accurate_localization_report_stats(filters)
          end

          def make_records(filter_attribute = nil, attribute_value = nil)
            make_localized_records(filter_attribute, attribute_value)
          end
        end
      end

      describe 'POST #background_report_metrics' do
        it_behaves_like "filter sharing" do
          let(:for_endpoint) { true }

          def it_filters(filters)
            it_returns_accurate_localization_report_metrics(filters)
          end

          def make_records(filter_attribute = nil, attribute_value = nil)
            make_localized_records(filter_attribute, attribute_value)
          end
        end

        context "when there are no filters applied" do
          before do
            create(:submission, survey: @survey, created_at: 1.day.ago)

            submission = create(:submission, survey: @survey, created_at: 1.day.ago, viewed_at: 1.day.ago, answers_count: 1)
            create(:answer, submission: submission, possible_answer: @possible_answer, created_at: submission.created_at)

            @survey.submission_caches.create(applies_to_date: submission.created_at.to_date, submission_count: 1,
                                             viewed_impression_count: 1, impression_count: 2)
          end

          it "returns accurate metrics" do
            it_returns_accurate_report_metrics({})
          end
        end
      end

      # TODO: Share this with other filtered endpoints
      describe 'when market (survey_id) filters are applied' do
        before do
          create(:submission, survey_id: @survey.id, answers_count: 0, created_at: viewed_impressions_enabled_at)
          make_localized_answer(@survey)

          create(:submission, survey_id: @duplicate_survey1.id, answers_count: 0, created_at: viewed_impressions_enabled_at)
          2.times { make_localized_answer(@duplicate_survey1) }

          create(:submission, survey_id: @duplicate_survey2.id, answers_count: 0, created_at: viewed_impressions_enabled_at)
          5.times { make_localized_answer(@duplicate_survey2) }
        end

        describe 'GET #localization_report_stats' do
          it "returns impression, submission and submission_rate for results belonging to the specified market" do
            filter = { market_ids: [@duplicate_survey1.id] }
            it_returns_accurate_localization_report_stats(filter)
          end
        end

        describe 'GET #background_report_metrics' do
          it "returns impression, submission and submission_rate for results belonging to the specified market" do
            filter = { market_ids: [@duplicate_survey1.id] }
            it_returns_accurate_localization_report_metrics(filter)
          end

          it "returns impression, submission and submission_rate for results belonging to any of multiple specified markets" do
            filter = { market_ids: [@duplicate_survey1.id, @duplicate_survey2.id] }
            it_returns_accurate_localization_report_metrics(filter)
          end
        end
      end
    end

    describe 'GET #page_event_data' do
      it 'rejects a logged out user' do
        user = create(:reporting_only_user, account: @survey.account)
        sign_out user

        get :page_event_data, params: { id: @survey.id }

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to sign_in_path
      end

      it 'allows a reporting user' do
        sign_in create(:reporting_only_user, account: @survey.account)
        get :page_event_data, params: { id: @survey.id }
        expect(response).to have_http_status(:ok)
      end

      it 'allows a full access user' do
        get :page_event_data, params: { id: @survey.id }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST #live_preview" do
    before do
      @user = create(:user)
      @survey = create(:survey, account: @user.account)
    end

    it "does not work when the user is not signed in" do
      input_url = "https://ekohe.com"

      post :live_preview, params: { id: @user.id, user: { live_preview_url: input_url, survey_id: @survey.id }}

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to sign_in_path

      expect(@user.live_preview_url).to be_nil
    end

    it "accepts https urls" do
      sign_in @user

      input_url = "https://ekohe.com"
      expected_url = input_url

      it_redirects_where_expected(input_url, expected_url)
    end

    it "converts http urls to https" do
      sign_in @user

      input_url = "http://ekohe.com"
      expected_url = "https://ekohe.com"

      it_redirects_where_expected(input_url, expected_url)
    end

    it "converts urls with no protocol to https" do
      sign_in @user

      input_url = "ekohe.com"
      expected_url = "https://ekohe.com"

      it_redirects_where_expected(input_url, expected_url)
    end

    def it_redirects_where_expected(input_url, expected_url)
      post :live_preview, params: { id: @user.id, user: { live_preview_url: input_url, survey_id: @survey.id }}

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("#{expected_url}?pi_live_preview=true&pi_present=#{@survey.id}")

      expect(@user.reload.live_preview_url).to eq(expected_url)
    end
  end

  describe "GET #ajax_report" do
    let(:account) { create(:account, viewed_impressions_enabled_at: FFaker::Time.datetime) }
    let(:survey) { create(:survey, account: account) }
    let(:submission) { create(:submission, survey: survey) }
    let(:answer) { create(:answer, submission: submission) }
    let(:valid_params) { { id: survey.id, possible_answer_id: nil } }

    context "when the user is not logged in" do
      it "redirects them to signin" do
        get :ajax_report, params: valid_params

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to sign_in_path
      end
    end

    # TODO: #2203 Test that a user signed in to a different account gets redirected

    context "when a reporting-only user is signed in" do
      it "succeeds" do
        sign_in create(:reporting_only_user, account: survey.account)

        get :ajax_report, params: valid_params

        expect(response).to have_http_status(:ok)
      end
    end

    context "when a full access-user is signed in" do
      before do
        sign_in create(:user, account: survey.account)
      end

      it "succeeds" do
        get :ajax_report, params: valid_params
        expect(response).to have_http_status(:ok)
      end

      it "returns an object having the expected keys" do
        get :ajax_report, params: valid_params
        expect(response).to have_http_status(:ok)
        expected_keys = %w(report report_data result)

        expect(json_response.keys).to match_array(expected_keys)
      end

      describe "report" do
        it "returns an accurate report object" do
          get :ajax_report, params: valid_params

          expect(response).to have_http_status(:ok)

          report = json_response["report"]
          expected_keys = %w(impression_sum submission_sum submission_rate)

          expect(report.keys).to match_array(expected_keys)
        end

        # Handles report, which is similar to #background_report_stats response
        it_behaves_like "filter sharing" do
          let(:for_endpoint) { true }
          let(:possible_answer) { survey.possible_answers.sort_by_position.last }

          def it_filters(filters)
            get :ajax_report, params: valid_params.merge(possible_answer_id: possible_answer.id, **filters)

            report_data = json_response["report"]

            filters = parse_filters(filters.merge(possible_answer_id: possible_answer.id))

            # TODO: test answer_id == 0
            submissions_scope = Submission.filtered_submissions(survey.submissions, filters: filters)

            expect(report_data["impression_sum"]).to eq(survey.blended_impressions_count(filters: filters))
            expect(report_data["submission_sum"]).to eq(Submission.filtered_submissions(submissions_scope, filters: filters).count)
            expect(report_data["submission_rate"]).to eq(survey.human_submission_rate(filters: filters))
          end

          def make_records(filter_attribute = nil, attribute_value = nil)
            make_non_localized_answers_for_possible_answer(survey, survey.possible_answers.first, filter_attribute, attribute_value)
            make_non_localized_answers_for_possible_answer(survey, survey.possible_answers.last, filter_attribute, attribute_value)
          end
        end
      end

      describe "report data" do
        it "returns an accurate report data object" do
          get :ajax_report, params: valid_params

          expect(response).to have_http_status(:ok)

          report_data = json_response["report_data"]
          expected_keys = %w(impression_sum submission_sum rate)

          expect(report_data.keys).to match_array(expected_keys)
        end

        # Handles report_data, which is equivalent to the #background_report_metrics response
        it_behaves_like "filter sharing" do
          let(:for_endpoint) { true }

          def it_filters(filters)
            get :ajax_report, params: valid_params.merge(filters)

            report_data = json_response["report_data"]

            filters = parse_filters(filters)

            record_has_accurate_report_metrics(survey, filters, json_object: report_data)
          end

          def make_records(filter_attribute = nil, attribute_value = nil)
            make_non_localized_answers_for_possible_answer(survey, survey.possible_answers.first, filter_attribute, attribute_value)
          end
        end
      end

      describe "result" do
        it "returns an accurate result object" do
          get :ajax_report, params: valid_params

          expect(response).to have_http_status(:ok)

          result = json_response["result"]
          expect(result.is_a?(Array)).to be true
          expect(result.length).to eq(survey.questions.length)

          result.each_with_index do |question_data, question_index|
            expect(question_data).to eq(survey.questions[question_index].filtered_answers_count(nil).stringify_keys)
          end
        end

        it_behaves_like "filter sharing" do
          let(:for_endpoint) { true }

          # TODO: Simplify this test
          # rubocop:disable Metrics/AbcSize
          def it_filters(filters)
            get :ajax_report, params: valid_params.merge(filters)

            result = json_response["result"]

            expect(result.is_a?(Array)).to be true
            expect(result.length).to eq(survey.questions.length)

            filters = parse_filters(filters)

            submissions = survey.submissions
            submissions = Submission.filtered_submissions(submissions, filters: filters)

            result.each_with_index do |question_data, question_index|
              expected_result = survey.questions[question_index].filtered_answers_count(submissions, filters: filters)

              expect(question_data["answers"]).to eq(expected_result[:answers].stringify_keys)
              expect(question_data["responses"]).to eq(expected_result[:responses])
              expect(question_data["ungrouped_responses"]).to eq(expected_result[:ungrouped_responses])
            end
          end

          def make_records(filter_attribute = nil, attribute_value = nil)
            make_non_localized_answers_for_possible_answer(survey, survey.possible_answers.first, filter_attribute, attribute_value)
          end
        end
      end
    end
  end

  def add_variety_of_language_surveys(base_survey)
    new_survey = base_survey.duplicate
    new_survey.language_code = "fr"
    new_survey.save

    new_survey = base_survey.duplicate
    new_survey.language_code = "de"
    new_survey.save

    3.times do |_i|
      new_survey = base_survey.duplicate
      new_survey.language_code = "en_gb"
      new_survey.save
    end
  end

  def record_has_accurate_report_stats(record, filters)
    expect(json_response['impression_count']).to eq(record.blended_impressions_count(filters: filters).to_s)
    expect(json_response['submission_count']).to eq(record.submissions_count(filters: filters).to_s)
    expect(json_response['submission_rate']).to eq(record.human_submission_rate(filters: filters).to_s)
  end

  def it_returns_accurate_report_stats(filter)
    post :background_report_stats, params: filter.merge(id: @survey.id)

    filter = parse_filters(filter)

    record_has_accurate_report_stats(@survey, filter)
  end

  def it_returns_accurate_localization_report_stats(filter)
    get :localization_report_stats, params: filter.merge(survey_locale_group_id: @survey_locale_group.id)

    filter = parse_filters(filter)

    record_has_accurate_report_stats(@survey_locale_group, filter)
  end

  def record_has_accurate_report_metrics(record, filters, json_object: json_response)
    expected_impression_sum = record.blended_impressions_count(filters: filters).to_f
    expected_submissions_sum = record.submissions_count(filters: filters).to_f
    expected_rate = record.submission_rate(filters: filters).to_f

    first_submission = Submission.filtered_submissions(Submission.all, filters: filters).order(:created_at).first
    timestamp = timezone.at(first_submission.created_at).to_date.to_datetime.to_i * 1000

    expect(json_object['impression_sum']).to contain_exactly([timestamp, expected_impression_sum])
    expect(json_object['submission_sum']).to contain_exactly([timestamp, expected_submissions_sum])
    expect(json_object['rate']).to contain_exactly([timestamp, expected_rate])
  end

  def it_returns_accurate_report_metrics(filter)
    get :background_report_metrics, params: filter.merge(id: @survey.id)

    filter = parse_filters(filter)

    record_has_accurate_report_metrics(@survey, filter)
  end

  def it_returns_accurate_localization_report_metrics(filter)
    get :localization_report_metrics, params: filter.merge(survey_locale_group_id: @survey_locale_group.id)

    filter = parse_filters(filter)

    record_has_accurate_report_metrics(@survey_locale_group, filter)
  end

  # non-localized
  def make_answer_for_filter(survey, possible_answer, submission_extras: {}, answer_extras: {}, question_id: nil)
    submission = create(:submission, survey: survey, **submission_extras)
    create(:answer, submission: submission, possible_answer: possible_answer, question_id: question_id || possible_answer&.question_id, **answer_extras)
  end

  def make_non_localized_answers_for_possible_answer(survey, possible_answer, filter_attribute = nil, attribute_value = nil)
    make_non_localized_answers(survey, possible_answer, filter_attribute, attribute_value)
  end

  def make_non_localized_answers_for_free_text_question(question, filter_attribute = nil, attribute_value = nil)
    make_non_localized_answers(question.survey, nil, filter_attribute, attribute_value, question_id: question.id, text_answer: FFaker::Lorem.phrase)
  end

  def make_non_localized_answers(survey, possible_answer, filter_attribute = nil, attribute_value = nil, question_id: nil, text_answer: nil)
    answer_extras = { text_answer: text_answer }

    if filter_attribute.nil?
      make_answer_for_filter(survey, possible_answer, question_id: question_id, answer_extras: answer_extras)
    elsif [:created_at, :device_type, :url, :pageview_count, :visit_count].include?(filter_attribute)
      make_answer_for_filter(
        survey, possible_answer, submission_extras: { filter_attribute => attribute_value }, question_id: question_id, answer_extras: answer_extras
      )
    elsif filter_attribute == :possible_answer_id
      if possible_answer
        target_possible_answer = PossibleAnswer.find_by(id: attribute_value).presence ||
                                 create(:possible_answer, id: attribute_value, question: possible_answer.question)

        included_submission = create(:submission, survey: survey)
        create(:answer, submission: included_submission, possible_answer: target_possible_answer)

        other_question = possible_answer.question.survey.questions.not_free_text_question.last

        # same submission different question
        create(:answer, submission: included_submission, possible_answer: other_question.possible_answers.sort_by_position.first)

        # different submission same possible answer
        create(:answer, submission: create(:submission, survey: survey), possible_answer: target_possible_answer)
      else
        make_answer_for_filter(survey, nil, question_id: question_id, answer_extras: answer_extras)
      end
    else
      raise "Unrecognized data type #{filter_attribute}"
    end
  end

  def build_thank_you_diagram_properties_attributes(survey, user)
    { id: create(:thank_you_diagram_properties, node_record_id: survey.id, user_id: user.id).id }
  end
end
