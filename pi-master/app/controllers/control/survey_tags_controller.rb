# frozen_string_literal: true

module Control
  class SurveyTagsController < BaseController
    before_action :fetch_tag, only: %i(destroy edit update)

    def index
      @tags = SurveyTag.where(account: current_user.account).order(:name)

      @audits = current_user.account.associated_audits.for_index(controller_name.classify) if current_user.admin?
    end

    def new
      @tag = SurveyTag.new
    end

    def create
      if SurveyTag.create(tag_params.merge(account_id: current_user.account_id))
        redirect_to survey_tags_path, notice: 'Tag was successfully created.'
      else
        render :edit
      end
    end

    def edit
      @audits = @tag.audits.descending if current_user.admin?
    end

    def update
      if @tag.update(tag_params)
        redirect_to survey_tags_path, notice: 'Tag was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      if @tag.destroy
        flash[:notice] = 'Tag was successfully destroyed.'
      else
        flash[:alert] = @tag.errors.full_messages.join(',')
      end

      redirect_to survey_tags_path
    end

    private

    def tag_params
      params.require(:survey_tag).permit(:name)
    end

    def fetch_tag
      @tag = SurveyTag.where(account: current_user.account).find_by(id: params[:id])

      redirect_to dashboard_url unless @tag
    end
  end
end
