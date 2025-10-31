# frozen_string_literal: true
module Control
  class PossibleAnswerLocaleGroupsController < BaseController
    before_action :require_full_access_user!, except: [:update_color]
    before_action :set_possible_answer_locale_group, only: %i(destroy localization_editor_edit_possible_answer_locale_group_modal update update_color)

    include RedirectHelper

    # TODO: Try to quiet these offenses without playing code golf
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def create
      survey_locale_group_ids = current_user.account.survey_locale_groups.pluck(:id)
      question_locale_group = QuestionLocaleGroup.find_by(id: params[:possible_answer_locale_group][:owner_record_id], owner_record_id: survey_locale_group_ids)

      redirect_to dashboard_path and return unless question_locale_group

      error_message = ""

      ActiveRecord::Base.transaction do
        possible_answer_locale_group = PossibleAnswerLocaleGroup.new(possible_answer_locale_group_create_params)

        if possible_answer_locale_group.save
          base_question = question_locale_group.questions.order(:created_at).first
          next_question_id = base_question.survey.questions.find_by(question_locale_group_id: params[:next_question_locale_group_id].to_i)&.id

          possible_answer_params = {
            content: params[:base_possible_answer_content],
            question_id: base_question.id,
            next_question_id: next_question_id,
            possible_answer_locale_group_id: possible_answer_locale_group.id
          }

          if base_question.multiple_choices_question?
            base_question.possible_answers.order(:position).last.update(next_question_id: nil)
          end

          new_possible_answer = PossibleAnswer.create(possible_answer_params)
          if new_possible_answer.persisted?
            redirect_to localization_editor_path(question_locale_group.survey_locale_group), notice: "PossibleAnswer was successfully created."
          else
            error_message = "PossibleAnswer: #{new_possible_answer.errors.full_messages.join(',')}"
            raise ActiveRecord::Rollback
          end
        else
          error_message = "PossibleAnswerLocaleGroup: #{possible_answer_locale_group.errors.full_messages.join(',')}"
        end
      end

      return if error_message.blank?

      redirect_to localization_editor_path(question_locale_group.survey_locale_group), alert: "Error: #{error_message}."
    end

    def update
      redirect_to dashboard_path and return unless @possible_answer_locale_group

      @possible_answer_locale_group.update(possible_answer_locale_group_update_params)

      @possible_answer_locale_group.possible_answers.each do |possible_answer|
        if survey = possible_answer.question.survey
          next_question_id = survey.questions.find_by(question_locale_group_id: params[:next_question_locale_group_id])&.id
          possible_answer.update(next_question_id: next_question_id)
        end
      end

      survey_locale_group = @possible_answer_locale_group.question_locale_group.survey_locale_group
      redirect_to localization_editor_path(survey_locale_group), notice: "PossibleAnswer group was was successfully updated."
    end

    def destroy
      redirect_to dashboard_path and return unless @possible_answer_locale_group

      survey_locale_group_id = @possible_answer_locale_group.question_locale_group.survey_locale_group.id

      ActiveRecord::Base.transaction do
        if @possible_answer_locale_group.possible_answers.destroy_all && @possible_answer_locale_group.destroy
          redirect_to localization_editor_path(survey_locale_group_id), alert: "Destroyed possible answer across all surveys."
        else
          redirect_to localization_editor_path(survey_locale_group_id), alert: "Failed to destroy records."
        end
      end
    end

    def update_color
      render json: { error: "invalid color" }, status: 400 and return if params[:color].blank?

      render json: :ok and return if @possible_answer_locale_group.update(report_color: params[:color])

      render json: { error: "invalid color" }, status: 400 and return
    end

    def localization_editor_edit_possible_answer_locale_group_modal
      unless @possible_answer_locale_group
        render json: :forbidden, status: 404
        return
      end

      render partial: 'control/surveys/localization/base_possible_answer_modal', locals: { modal_id: params[:modal_id] }
    end

    private

    def set_possible_answer_locale_group
      @possible_answer_locale_group = PossibleAnswerLocaleGroup.find_by(
        id: params[:id],
        owner_record_id: current_user.account.question_locale_groups.pluck(:id)
      )

      handle_missing_record unless @possible_answer_locale_group
    end

    def possible_answer_locale_group_create_params
      params.require(:possible_answer_locale_group).permit([:name, :owner_record_id])
    end

    def possible_answer_locale_group_update_params
      possible_answer_locale_group_params = [:name]

      associated_model_params = [
        {possible_answers_attributes: [:id, :content]}
      ]

      accepted_params = possible_answer_locale_group_params + associated_model_params

      params.require(:possible_answer_locale_group).permit(accepted_params)
    end
  end
end
