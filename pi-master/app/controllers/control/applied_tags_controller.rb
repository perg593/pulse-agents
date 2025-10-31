# frozen_string_literal: true
module Control
  class AppliedTagsController < BaseController
    before_action :require_full_access_user!, only: [:create_for_answers, :remove_from_answers]
    before_action :require_same_account, only: [:create_for_answers, :remove_from_answers]
    before_action :set_applied_tag, only: %i(approve remove)

    include RedirectHelper

    def approve
      @applied_tag.update(is_good_automation: true)
      render json: {}, status: :ok
    end

    def remove
      @applied_tag.destroy
      render json: {}, status: :ok
    end

    def create_for_answers
      result = { response: [] }

      params[:answer_ids].each do |answer_id|
        AppliedTag.create(answer_id: answer_id, tag_id: params[:tag_id])

        result[:response] << Schemas.applied_tag_schema(answer_id)
      end

      render json: result, status: :ok
    end

    def remove_from_answers
      result = { response: [] }

      AppliedTag.where(answer_id: params[:answer_ids], tag_id: params[:tag_id]).destroy_all

      params[:answer_ids].each do |answer_id|
        result[:response] << Schemas.applied_tag_schema(answer_id)
      end

      render json: result, status: :ok
    end

    private

    def require_same_account
      tag_belongs_to_same_account = Tag.find(params[:tag_id]).question.survey.account == current_account

      answers_belong_to_same_account = Answer.includes(question: :survey).where(id: params[:answer_ids]).all? do |answer|
        answer.question.survey.account == current_account
      end

      redirect_to dashboard_path and return unless tag_belongs_to_same_account && answers_belong_to_same_account
    end

    # Ensure tags outside the current account don't get modified
    def set_applied_tag
      @applied_tag = AppliedTag.joins(tag: { question: { survey: :account } }).
                     where(accounts: { id: current_account.id }, questions: { id: params[:question_id] }).
                     find_by(id: params[:id])

      render json: {}, status: :not_found and return unless @applied_tag
    end
  end
end
