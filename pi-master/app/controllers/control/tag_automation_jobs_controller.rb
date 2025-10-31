# frozen_string_literal: true

module Control
  class TagAutomationJobsController < BaseController
    before_action :set_tag_automation_job, only: :poll

    include RedirectHelper

    def poll
      if @tag_automation_job.completed?
        applied_tag_data = @tag_automation_job.applied_tags.map do |applied_tag|
          { name: applied_tag.tag.name,
            color: applied_tag.tag.color,
            answerId: applied_tag.answer_id,
            appliedTagId: applied_tag.id,
            id: applied_tag.tag_id }
        end
        render json: { status: @tag_automation_job.status, appliedTags: applied_tag_data }, status: :ok
      else
        render json: { status: @tag_automation_job.status }, status: :ok
      end
    end

    def set_tag_automation_job
      @tag_automation_job = TagAutomationJob.where(question: Question.where(survey: current_account.surveys)).find_by(id: params[:id])
      handle_missing_record unless @tag_automation_job
    end
  end
end
