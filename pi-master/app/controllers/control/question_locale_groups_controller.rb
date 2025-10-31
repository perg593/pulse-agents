# frozen_string_literal: true
module Control
  class QuestionLocaleGroupsController < BaseController
    before_action :require_full_access_user!

    def destroy
      @question_locale_group = QuestionLocaleGroup.where(id: params[:id], owner_record_id: current_user.account.survey_locale_groups.pluck(:id)).first

      unless @question_locale_group
        redirect_to dashboard_path and return
      end

      survey_locale_group_id = @question_locale_group.owner_record_id

      ActiveRecord::Base.transaction do
        if @question_locale_group.possible_answer_locale_groups.destroy_all && @question_locale_group.questions.destroy_all && @question_locale_group.destroy
          redirect_to localization_editor_path(survey_locale_group_id), alert: "Destroyed question across all surveys."
        else
          redirect_to localization_editor_path(survey_locale_group_id), alert: "Failed to destroy records."
        end
      end
    end

    def update
      @question_locale_group = QuestionLocaleGroup.where(id: params[:id], owner_record_id: current_user.account.survey_locale_groups.pluck(:id)).first

      unless @question_locale_group
        redirect_to dashboard_path and return
      end

      if @question_locale_group.update(question_locale_group_params)
        num_questions = @question_locale_group.questions.count
        success_message = "Updated #{num_questions} #{'question'.pluralize(num_questions)}"
        redirect_to localization_editor_path(@question_locale_group.owner_record_id), notice: success_message
      else
        error_message = "Failed to update. #{@question_locale_group.errors.full_messages.join(', ') if current_user.admin?}"
        redirect_to localization_editor_path(@question_locale_group.owner_record_id), alert: error_message
      end
    end

    def localization_editor_edit_base_question_modal
      survey_locale_group_ids = current_user.account.survey_locale_groups.pluck(:id)
      unless question_locale_group = QuestionLocaleGroup.find_by(id: params[:question_locale_group_id], owner_record_id: survey_locale_group_ids)
        render json: :forbidden, status: 404 and return
      end

      render partial: 'control/surveys/localization/base_question_modal', locals: { modal_id: params[:modal_id], question_locale_group: question_locale_group }
    end

    private

    # A bit of a mess because fields for the question are coming in three structures:
    # [:question_locale_group]["0"]
    # [:question_locale_group]["1"]
    # and the optional
    # [:survey][:form_questions_attributes]["0"]
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def question_locale_group_params
      # These are specified outside of the "survey" param used by simple_form_for
      extra_questions_attributes = [:id, :randomize, :enable_maximum_selection, :maximum_selection]

      question_type_params = params.delete(:survey)[:form_questions_attributes]["0"] if params[:survey]
      first_extra_questions_attributes_params = params[:question_locale_group][:questions_attributes].delete("0").permit(extra_questions_attributes)

      second_extra_questions_attributes_params = params[:question_locale_group][:questions_attributes].delete("1")
      second_extra_questions_attributes_params = second_extra_questions_attributes_params&.permit(extra_questions_attributes)

      accepted_question_type_params = [
        {
          questions_attributes:
          [
            :id, :button_type, :desktop_width_type, :answers_per_row_desktop, :answers_alignment_desktop, :mobile_width_type, :answers_per_row_mobile,
            :answers_alignment_mobile, :before_answers_count, :before_answers_items,
            :after_answers_count, :after_answers_items, :height, :max_length, :fullscreen, :background_color, :opacity,
            :autoclose_enabled, :autoclose_delay, :autoredirect_enabled, :autoredirect_url, :autoredirect_delay, :free_text_next_question_id, :survey_id
          ] + extra_questions_attributes
        }
      ]

      question_type_params = question_type_params&.permit(accepted_question_type_params[0][:questions_attributes])

      question_locale_group_params = [:name]
      accepted_params = question_locale_group_params + accepted_question_type_params

      vetted_params = params.require(:question_locale_group).permit(accepted_params)

      final_question_attributes_params = first_extra_questions_attributes_params
      final_question_attributes_params.merge!(second_extra_questions_attributes_params) if second_extra_questions_attributes_params
      final_question_attributes_params.merge!(question_type_params) if question_type_params

      # Duplicate the accepted question attributes, copying them once for each
      # question in the question locale group.
      all_questions_attributes = {}

      next_question_locale_group = QuestionLocaleGroup.find_by(id: params[:next_question_locale_group_id]) if params[:next_question_locale_group_id]

      @question_locale_group.questions.each_with_index do |question, question_index|
        all_questions_attributes[question_index.to_s] = {}.merge!(final_question_attributes_params)
        all_questions_attributes[question_index.to_s][:id] = question.id

        next unless params[:next_question_locale_group_id]

        all_questions_attributes[question_index.to_s][:free_text_next_question_id] = if next_question_locale_group
          next_question_locale_group.questions.find_by(survey_id: question.survey_id).id
        end
      end

      # Do we need to specify question ID if we're already passing an index?
      # What does that index correspond to though? question_locale_group.questions[index]?
      vetted_params.merge!({ questions_attributes: all_questions_attributes })

      vetted_params.permit(accepted_params)
    end
  end
end
