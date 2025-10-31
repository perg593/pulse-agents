# frozen_string_literal: true
module Control
  class TagsController < BaseController
    DEFAULT_TAG_COLOR = '#000000'

    def bulk_approve
      redirect_to dashboard_url and return unless answer_ids_belong_to_account?(params[:answer_ids])

      approved_tags = params[:answer_ids].map do |answer_id|
        # The current spec is that an answer can get max 1 automated tag
        next unless applied_tag = AppliedTag.automated.where(answer_id: answer_id).first
        next unless applied_tag.update(is_good_automation: true)

        { answer_id: answer_id.to_i, applied_tag_id: applied_tag.id }
      end.compact

      render json: { tags: approved_tags }, status: :ok
    end

    def bulk_remove
      # https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/1731#note_838025
      # Support the old design where a user can select a tag to delete because the new design is featured flagged
      if tag = Tag.find_by(question_id: params[:question_id], name: params[:tag_name])
        redirect_to dashboard_url and return unless tag_belongs_to_account?(tag)
      else
        redirect_to dashboard_url and return unless answer_ids_belong_to_account?(params[:answer_ids])
      end

      applied_tags = AppliedTag.order(:created_at)
      applied_tags = applied_tags.where(tag: tag) if tag

      removed_tags = params[:answer_ids].map do |answer_id|
        next unless applied_tag = applied_tags.find_by(answer_id: answer_id)
        next unless applied_tag.destroy

        { answer_id: answer_id.to_i, applied_tag_id: applied_tag.id }
      end.compact

      render json: { tags: removed_tags }, status: :ok
    end

    def bulk_add
      question = Question.find_by(id: params[:question_id])
      redirect_to dashboard_url and return unless question.survey.account == current_user.account

      tag ||= question.tags.create_with(color: DEFAULT_TAG_COLOR).find_or_create_by(name: params[:tag_name])

      answers = Answer.where(id: params[:answer_ids], question: question)
      answers.each { |answer| answer.tags << tag }

      result = { response: [] }

      params[:answer_ids].each do |answer_id|
        result[:response] << Schemas.applied_tag_schema(answer_id)
      end

      render json: result, status: :ok
    end

    private

    def answer_ids_belong_to_account?(answer_ids)
      account_ids = Answer.where(id: answer_ids).joins(question: :survey).select(surveys: :account_id).pluck(:account_id).uniq

      account_ids.length == 1 && account_ids.first == current_user.account.id
    end

    def tag_belongs_to_account?(tag)
      tag.question.survey.account == current_user.account
    end
  end
end
