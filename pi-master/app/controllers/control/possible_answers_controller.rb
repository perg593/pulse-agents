# frozen_string_literal: true
module Control
  class PossibleAnswersController < BaseController
    layout :resolve_layout

    skip_before_action :verify_authenticity_token, only: :update
    before_action :require_full_access_user!, except: [:update_settings, :remove_image]

    def update_settings
      possible_answer = PossibleAnswer.find(params[:id])
      question = possible_answer.question

      question.update(image_settings: pa_params[:image_settings].to_i)

      possible_answer.update(image_alt: pa_params[:image_alt],
                             image_width: pa_params[:image_width],
                             image_width_mobile: pa_params[:image_width_mobile],
                             image_width_tablet: pa_params[:image_width_tablet],
                             image_height: pa_params[:image_height],
                             image_height_mobile: pa_params[:image_height_mobile],
                             image_height_tablet: pa_params[:image_height_tablet],
                             image_position_cd: pa_params[:image_position_cd].to_i)

      update_answer_image(possible_answer, question.survey.account)

      redirect_back(fallback_location: root_path)
    end

    def remove_image
      possible_answer = PossibleAnswer.find(params[:id])

      possible_answer.update(answer_image_id: nil,
                             image_position_cd: nil,
                             image_alt: nil,
                             image_height: nil,
                             image_width: nil,
                             image_height_mobile: nil,
                             image_width_mobile: nil,
                             image_height_tablet: nil,
                             image_width_tablet: nil)

      redirect_back(fallback_location: root_path)
    end

    def localization_editor_new_possible_answer_modal
      survey_locale_group_ids = current_user.account.survey_locale_groups.pluck(:id)
      unless question_locale_group = QuestionLocaleGroup.find_by(id: params[:question_locale_group_id], owner_record_id: survey_locale_group_ids)
        render json: :forbidden, status: 404 and return
      end

      render partial: 'control/surveys/localization/new_possible_answer_modal',
             locals: {
               modal_id: params[:modal_id],
               question_locale_group: question_locale_group
             }
    end

    def localization_editor_possible_answer_image_modal
      possible_answer = PossibleAnswer.find_by(id: params[:possible_answer_id])

      unless current_user.account.surveys.find_by(id: possible_answer.question.survey)
        render json: :forbidden, status: 404 and return
      end

      render partial: "control/surveys/localization/possible_answer_image_modal", locals: { modal_id: params[:modal_id], possible_answer: possible_answer }
    end

    def update_color
      possible_answer = PossibleAnswer.find(params[:id])

      if possible_answer.question.survey.account_id != current_user.account_id
        render json: :forbidden, status: 404 and return
      end

      render json: { error: "invalid color" }, status: 400 and return if params[:color].blank?

      render json: :ok and return if possible_answer.update(report_color: params[:color])

      render json: { error: "invalid color" }, status: 400 and return
    end

    private

    def update_answer_image(possible_answer, account)
      if pa_params[:image]
        answer_image = AnswerImage.create(image: pa_params[:image], imageable: account)
        possible_answer.update(answer_image_id: answer_image.id)
      elsif pa_params[:answer_image_id]
        possible_answer.update(answer_image_id: pa_params[:answer_image_id])
      end
    end

    def pa_params
      params.require(:possible_answer).permit(:image, :image_settings, :image_alt, :image_height, :image_width, :answer_image_id, :image_position_cd,
                                              :image_height_mobile, :image_width_mobile, :image_height_tablet, :image_width_tablet)
    end
  end
end
