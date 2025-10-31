# frozen_string_literal: true
require 'spec_helper'

describe Control::QuestionLocaleGroupsController do
  before do
    Account.delete_all
    User.delete_all
    Invitation.delete_all
    Survey.delete_all
    Question.delete_all
  end

  describe "DELETE #delete" do
    it "is not available to reporting level users" do
      user = create(:reporting_only_user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      delete :destroy, params: { id: base_survey.survey_locale_group.question_locale_groups.first.id }

      expect_redirected_to_dashboard
    end

    it 'is not possible for users not belonging to the account that owns the SurveyLocaleGroup' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: create(:account))

      delete :destroy, params: { id: base_survey.survey_locale_group.question_locale_groups.first.id }

      expect_redirected_to_dashboard
    end

    it 'is possible for full access users' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)
      localized_survey = base_survey.duplicate
      localized_survey.save

      # confirm that all surveys had this question
      question_locale_group = base_survey.survey_locale_group.question_locale_groups.first
      target_questions = Question.where(question_locale_group_id: question_locale_group.id)
      expect(target_questions.many?).to be true

      target_possible_answer_locale_groups = question_locale_group.possible_answer_locale_groups
      expect(target_possible_answer_locale_groups.many?).to be true

      old_possible_answer_count = PossibleAnswer.count
      expect(old_possible_answer_count).not_to eq(0)

      delete :destroy, params: { id: question_locale_group.id }

      base_survey.reload
      expect(Question.where(id: target_questions.map(&:id))).to eq([])
      expect(PossibleAnswerLocaleGroup.where(id: target_possible_answer_locale_groups.map(&:id))).to eq([])
      expect(PossibleAnswer.count).to eq(old_possible_answer_count)

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))
    end
  end

  describe "PATCH #update" do
    it "is not available to reporting level users" do
      user = create(:reporting_only_user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      patch :update, params: { id: base_survey.survey_locale_group.question_locale_groups.first.id, question_locale_group: { meaningless: :placeholder }}

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("http://test.host/dashboard")
    end

    it 'is not possible for users not belonging to the account that owns the SurveyLocaleGroup' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: create(:account))

      patch :update, params: { id: base_survey.survey_locale_group.question_locale_groups.first.id, question_locale_group: { meaningless: :placeholder }}

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq("http://test.host/dashboard")
    end

    it 'is possible for full access users' do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)

      patch :update, params: {
        id: base_survey.survey_locale_group.question_locale_groups.first.id,
        question_locale_group: {
          questions_attributes: {
            "0" => { meaningless: :placeholder }
          }
        }
      }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))
    end

    it "updates records for all questions in locale group when valid values are provided" do
      user = create(:user)
      sign_in user

      base_survey = create(:localized_survey, account: user.account)
      base_survey.duplicate.save

      old_question_count = Question.count
      old_question_locale_group_count = QuestionLocaleGroup.count

      question_locale_group = base_survey.survey_locale_group.question_locale_groups.first
      new_name = "new question locale group name"

      question_locale_group.questions.each do |question|
        question.update(randomize: Question::RANDOMIZE_ALL_EXCEPT_LAST)
      end

      new_randomization = Question::RANDOMIZE_ALL

      patch :update, params: {
        id: base_survey.survey_locale_group.question_locale_groups.first.id,
        question_locale_group: {
          name: new_name,
          questions_attributes: {
            "0" => {
              randomize: new_randomization
            }
          }
        }
      }

      expect(Question.count).to eq(old_question_count)
      expect(QuestionLocaleGroup.count).to eq(old_question_locale_group_count)

      question_locale_group.reload

      question_locale_group.questions.each do |question|
        expect(question.randomize).to eq(new_randomization)
      end

      expect(question_locale_group.name).to eq(new_name)

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))
    end

    it "can update free_text_next_question_id across surveys" do
      user = create(:user)
      sign_in user

      base_survey = create(:survey_without_question, account: user.account, language_code: "en_ca")

      q1 = create(:free_text_question, survey_id: base_survey.id, position: 0)
      q2 = create(:question, survey_id: base_survey.id, position: 1)
      q3 = create(:question, survey_id: base_survey.id, position: 2)

      q1.update(free_text_next_question_id: q2.id)

      base_survey.reload
      base_survey.localize!

      duplicated_survey = base_survey.duplicate
      duplicated_survey.save
      duplicated_survey.reattach_plumbing_lines(base_survey)
      duplicated_survey.reload

      duplicate_q1 = duplicated_survey.questions[0]
      duplicate_q2 = duplicated_survey.questions[1]
      duplicate_q3 = duplicated_survey.questions[2]

      q1.reload
      q3.reload

      expect(q1.free_text_next_question_id).to eq q2.id
      expect(duplicate_q1.free_text_next_question_id).to eq duplicate_q2.id

      patch :update, params: {
        id: q1.question_locale_group_id,
        question_locale_group: {
          questions_attributes: {
            "0" => { meaningless: :placeholder }
          }
        },
        next_question_locale_group_id: q3.question_locale_group_id
      }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))

      q1.reload
      duplicate_q1.reload

      expect(q1.free_text_next_question_id).to eq q3.id
      expect(duplicate_q1.free_text_next_question_id).to eq duplicate_q3.id
    end

    it "can wipe free_text_next_question_id across surveys" do
      user = create(:user)
      sign_in user

      base_survey = create(:survey_without_question, account: user.account, language_code: "en_ca")

      q1 = create(:free_text_question, survey_id: base_survey.id, position: 0)
      q2 = create(:question, survey_id: base_survey.id, position: 1)
      q3 = create(:question, survey_id: base_survey.id, position: 2)

      q1.update(free_text_next_question_id: q2.id)

      base_survey.reload
      base_survey.localize!

      duplicated_survey = base_survey.duplicate
      duplicated_survey.save
      duplicated_survey.reattach_plumbing_lines(base_survey)
      duplicated_survey.reload

      duplicate_q1 = duplicated_survey.questions[0]
      duplicate_q2 = duplicated_survey.questions[1]
      duplicate_q3 = duplicated_survey.questions[2]

      q1.reload
      q3.reload

      expect(q1.free_text_next_question_id).to eq q2.id
      expect(duplicate_q1.free_text_next_question_id).to eq duplicate_q2.id

      patch :update, params: {
        id: q1.question_locale_group_id,
        question_locale_group: {
          questions_attributes: {
            "0" => { meaningless: :placeholder }
          }
        },
        next_question_locale_group_id: nil
      }

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))

      q1.reload
      duplicate_q1.reload

      expect(q1.free_text_next_question_id).to be_nil
      expect(duplicate_q1.free_text_next_question_id).to be_nil
    end
  end
end
