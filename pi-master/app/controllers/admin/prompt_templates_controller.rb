# frozen_string_literal: true

module Admin
  class PromptTemplatesController < Admin::BaseController
    before_action :set_prompt_template, only: [:show, :edit, :update, :destroy]

    def index
      @prompt_templates = PromptTemplate.order(:name)

      respond_to do |format|
        format.html
        format.json { render json: @prompt_templates.as_json(only: [:id, :name, :content, :is_default]) }
      end
    end

    def show; end

    def new
      @prompt_template = PromptTemplate.new
    end

    def edit; end

    def create
      @prompt_template = PromptTemplate.new(prompt_template_params)

      if @prompt_template.save
        redirect_to admin_prompt_template_path(@prompt_template), notice: "Prompt template was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @prompt_template.update(prompt_template_params)
        redirect_to admin_prompt_template_path(@prompt_template), notice: "Prompt template was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @prompt_template.destroy
      redirect_to admin_prompt_templates_path, notice: "Prompt template was successfully deleted."
    end

    private

    def set_prompt_template
      @prompt_template = PromptTemplate.find(params[:id])
    end

    def prompt_template_params
      params.require(:prompt_template).permit(:name, :content, :is_default)
    end
  end
end
