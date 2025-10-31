# frozen_string_literal: true
require 'spec_helper'

describe Control::PossibleAnswerLocaleGroupsController do
  before do
    Account.delete_all
    User.delete_all
    Invitation.delete_all
    Survey.delete_all
    Question.delete_all
    PossibleAnswer.delete_all
    PossibleAnswerLocaleGroup.delete_all
  end

  describe "PossibleAnswerLocaleGroup requirement" do
    it "redirects to the survey dashboard when the possible answer locale group is not found" do
      sign_in create(:user)

      endpoints = [
        { verb: :get, url: :destroy },
        { verb: :get, url: :localization_editor_edit_possible_answer_locale_group_modal, json: :always },
        { verb: :get, url: :update, json: :always },
        { verb: :get, url: :update_color, json: :always }
      ]

      endpoints.each do |endpoint|
        it_handles_missing_records(endpoint)
      end
    end
  end

  describe "PATCH #update_color" do
    let(:user) { create(:user) }
    let(:old_color) { "#00f" }
    let(:survey) { create(:localized_survey, account: user.account) }
    let(:valid_color) { "#f00" }
    let(:record) do
      possible_answer_locale_group = survey.possible_answers.first.possible_answer_locale_group
      possible_answer_locale_group.update(report_color: old_color)
      possible_answer_locale_group
    end

    include_examples "color update"

    it "does not update the report_color of any possible_answers in the group" do
      sign_in user

      new_color = valid_color
      expect(record.possible_answers.none? { |possible_answer| possible_answer.report_color == new_color }).to be true

      patch :update_color, params: { id: record.id, color: new_color }

      record.reload
      expect(record.possible_answers.none? { |possible_answer| possible_answer.report_color == new_color }).to be true
    end
  end

  describe "DELETE #delete" do
    it "is not available to reporting level users" do
      user = create(:reporting_only_user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      delete :destroy, params: { id: base_survey.survey_locale_group.question_locale_groups.first.possible_answer_locale_groups.pick(:id) }

      expect_redirected_to_dashboard
    end

    it 'is not possible for users not belonging to the account that owns the SurveyLocaleGroup' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: create(:account))

      delete :destroy, params: { id: base_survey.survey_locale_group.question_locale_groups.first.possible_answer_locale_groups.pick(:id) }

      expect_redirected_to_dashboard
    end

    it 'is possible for full access users' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)
      localized_survey = base_survey.duplicate
      localized_survey.save

      possible_answer_locale_group = base_survey.survey_locale_group.question_locale_groups.first.possible_answer_locale_groups.first
      possible_answers = possible_answer_locale_group.possible_answers

      delete :destroy, params: { id: possible_answer_locale_group.id }

      base_survey.reload

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))

      expect(PossibleAnswerLocaleGroup.find_by(id: possible_answer_locale_group.id)).to be_nil
      expect(PossibleAnswer.where(id: possible_answers.ids).empty?).to be true
    end
  end

  describe "PATCH #update" do
    it "is not available to reporting level users" do
      user = create(:reporting_only_user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      patch :update, params: {
        id: base_survey.possible_answers.first.possible_answer_locale_group_id,
        possible_answer_locale_group: {
          meaningless: :placeholder
        }
      }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("http://test.host/dashboard")
    end

    it 'is not possible for users not belonging to the account that owns the SurveyLocaleGroup' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: create(:account))

      patch :update, params: {
        id: base_survey.possible_answers.first.possible_answer_locale_group_id,
        possible_answer_locale_group: {
          meaningless: :placeholder
        }
      }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("http://test.host/dashboard")
    end

    it 'is possible for full access users' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      patch :update, params: {
        id: base_survey.possible_answers.first.possible_answer_locale_group_id,
        possible_answer_locale_group: {
          meaningless: :placeholder
        }
      }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))
    end

    it "updates records when valid values are provided" do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      old_possible_answer_count = base_survey.possible_answers.count
      old_possible_answer_locale_group_count = base_survey.possible_answers.count

      expect(PossibleAnswer.count).to eq(old_possible_answer_count)
      expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count)

      possible_answer_locale_group = PossibleAnswerLocaleGroup.last
      old_name = possible_answer_locale_group.name
      new_name = "new possible answer locale group name"

      possible_answer = possible_answer_locale_group.possible_answers.first
      old_content = possible_answer.content
      new_content = "new possible answer content"

      patch :update, params: {
        id: possible_answer_locale_group.id,
        possible_answer_locale_group: {
          name: new_name,
          possible_answers_attributes: {
            id: possible_answer.id,
            content: new_content
          }
        }
      }

      expect(PossibleAnswer.count).to eq(old_possible_answer_count)
      expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count)

      possible_answer.reload
      expect(possible_answer.content).to eq(new_content)

      possible_answer_locale_group.reload
      expect(possible_answer_locale_group.name).to eq(new_name)
    end
  end

  describe "POST #create" do
    it "is not available to reporting level users" do
      user = create(:reporting_only_user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      post :create, params: { possible_answer_locale_group: { owner_record_id: base_survey.questions.first.question_locale_group_id }}

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("http://test.host/dashboard")
    end

    it 'is not possible for users not belonging to the account that owns the SurveyLocaleGroup' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: create(:account))

      post :create, params: { possible_answer_locale_group: { owner_record_id: base_survey.questions.first.question_locale_group_id }}

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("http://test.host/dashboard")
    end

    it 'is possible for full access users' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      post :create, params: { possible_answer_locale_group: { owner_record_id: base_survey.questions.first.question_locale_group_id }}

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))
    end

    it "creates new records when all required fields are provided" do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      old_possible_answer_count = base_survey.possible_answers.count
      old_possible_answer_locale_group_count = base_survey.possible_answers.count

      expect(PossibleAnswer.count).to eq(old_possible_answer_count)
      expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count)

      post :create, params: {
        possible_answer_locale_group: {
          owner_record_id: base_survey.questions.first.question_locale_group_id,
          name: "new short name"
        },
        base_possible_answer_content: "new possible answer"
      }

      expect(PossibleAnswer.count).to eq(old_possible_answer_count + 1)
      expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count + 1)
    end

    it "creates no new records when any required field is not provided" do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      old_possible_answer_count = base_survey.possible_answers.count
      old_possible_answer_locale_group_count = base_survey.possible_answers.count

      expect(PossibleAnswer.count).to eq(old_possible_answer_count)
      expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count)

      required_params = {
        possible_answer_locale_group: {
          owner_record_id: base_survey.questions.first.question_locale_group_id,
          name: "new short name"
        },
        base_possible_answer_content: "new possible answer"
      }

      post :create, params: required_params.merge(base_possible_answer_content: nil)

      expect(PossibleAnswer.count).to eq(old_possible_answer_count)
      expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count)

      post :create, params: required_params.deep_merge(possible_answer_locale_group: {owner_record_id: nil})

      expect(PossibleAnswer.count).to eq(old_possible_answer_count)
      expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count)

      post :create, params: required_params.deep_merge(possible_answer_locale_group: {name: nil})

      expect(PossibleAnswer.count).to eq(old_possible_answer_count)
      expect(PossibleAnswerLocaleGroup.count).to eq(old_possible_answer_locale_group_count)
    end

    context "when creating for a multiple choice question" do
      before do
        user = create(:user)
        sign_in user

        base_survey = create(:survey_with_one_multiple_question, account: user.account)
        @multiple_choice_question = base_survey.questions.reload.first

        question_to_route_to = create(:single_choice_question, survey: base_survey)
        base_survey.questions << question_to_route_to

        @multiple_choice_question.possible_answers.last.update(next_question_id: question_to_route_to.id)

        base_survey.localize!

        post :create, params: {
          possible_answer_locale_group: {
            owner_record_id: @multiple_choice_question.question_locale_group_id,
            name: "new short name"
          },
          base_possible_answer_content: "new possible answer"
        }
      end

      it "removes the routing from the second last possible answer" do
        expect(@multiple_choice_question.reload.possible_answers.order(:position).second_to_last.next_question_id).to be_nil
      end
    end
  end
end
