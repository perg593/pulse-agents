# frozen_string_literal: true

module Control
  class AutomationsController < BaseController
    before_action :set_automation, only: %i(edit update destroy)
    before_action :set_emails, only: [:new, :edit, :create, :update]
    before_action :set_questions, only: [:new, :edit, :create, :update]
    before_action :set_conditions, only: :edit
    before_action :set_actions, only: :edit

    def index
      @automations = current_account.automations

      @audits = current_user.account.associated_audits.for_index(controller_name.classify) if current_user.admin?
    end

    def new
      @automation = Automation.new(account_id: current_user.account_id)
      @automation.conditions.build
      @automation.actions.build

      @questions = Question.where(survey_id: current_user.surveys.live.pluck(:id))
    end

    def create
      @automation = Automation.new(automation_params)
      @automation.account_id = current_user.account.id

      if @automation.save
        redirect_to automations_path, notice: 'Automation was successfully created.'
      else
        flash.now.alert = @automation.errors.full_messages.join(', ')
        render :new
      end
    end

    def edit
      @audits = @automation.own_and_associated_audits.descending if current_user.admin?
    end

    def update
      result = @automation.transaction do
        @automation.actions.delete_all
        @automation.conditions.delete_all
        @automation.update!(automation_params)
      rescue ActiveRecord::RecordInvalid
        raise ActiveRecord::Rollback
      end

      if result
        redirect_to automations_path, notice: 'Automation was successfully updated.'
      else
        flash.alert = @automation.errors.full_messages.join(', ')
        redirect_back(fallback_location: automation_path)
      end
    end

    def destroy
      @automation.destroy

      redirect_to automations_path, notice: 'Automation was successfully destroyed.'
    end

    private

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity Prioritize readability because it's a bit complex
    def automation_params
      p = params.require(:automation).permit(:name, :enabled, :condition_type, :action_type, :trigger_type,
                                             conditions_attributes: [:question_id, :url_matcher, :condition, :_destroy],
                                             actions_attributes: [{email: []}, :event_name, :event_properties, :_destroy])

      # Delete empty conditions and actions
      p[:conditions_attributes]&.delete_if { |_k, v| v[:condition] == '' || v[:_destroy] == '1' }
      p[:actions_attributes]&.delete_if { |_k, v| v[:email]&.uniq == [''] || (v[:event_name] == '' || v[:event_properties] == '') || v[:_destroy] == '1' }

      # Trim "" from emails
      p[:actions_attributes]&.each_value { |v| v[:email] = v[:email].reject(&:empty?).last if v[:email].present? }

      # Remove url & event pairs if the automation is "answer_text" type
      p[:conditions_attributes]&.delete_if { |_k, v| v[:url_matcher].present? } if p[:condition_type] == 'answer_text'
      p[:actions_attributes]&.delete_if { |_k, v| v[:event_name].present? } if p[:action_type] == 'send_email'

      # Remove question & email pairs if the automation is "url" type
      p[:conditions_attributes]&.delete_if { |_k, v| v[:url_matcher].blank? } if p[:condition_type] == 'url'
      p[:actions_attributes]&.delete_if { |_k, v| v[:email].present? } if p[:action_type] == 'create_event'

      p
    end

    def set_automation
      @automation = current_account.automations.find_by(id: params[:id])

      redirect_to dashboard_url unless @automation
    end

    def set_questions
      @questions = Question.where(survey_id: current_user.surveys.live.pluck(:id))
    end

    def set_emails
      @emails = current_account.users.pluck(:email).map { |email| AutomationAction.new(email: email) }
    end

    def set_conditions
      @answer_text_conditions = @automation.conditions.where(url_matcher: nil)
      @answer_text_conditions = @automation.conditions.build if @answer_text_conditions.count.zero?
      @url_condition = @automation.conditions.where.not(url_matcher: nil)
      @url_condition = @automation.conditions.build if @url_condition.count.zero?
    end

    def set_actions
      @event_action = @automation.actions.where.not(event_name: nil)
      @event_action = @automation.actions.build if @event_action.count.zero?
    end
  end
end
