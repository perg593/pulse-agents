# frozen_string_literal: true

module Control
  class QuestionsController < BaseController
    skip_before_action :verify_authenticity_token, only: :update
    before_action :require_full_access_user!, only: [:auto_tag_answers, :update, :require_full_access_user!, :create]
    before_action :set_question, only: %i(auto_tag_answers toggle_tag_automation_worker update create_tag update_tag delete_tag ai_tag_recommendations)
    before_action :set_survey_locale_group, only: [:create]
    before_action :require_tag_automation, only: %i(auto_tag_answers toggle_tag_automation_worker)

    include DatesHelper
    include FiltersHelper
    include RedirectHelper

    # Only used by the Localization Bulk Editor
    def create
      if params[:for_base_survey]
        base_survey_question
      elsif params[:for_localized_survey]
        create_non_base_survey_question
      end
    end

    def localization_editor_new_base_question_modal
      unless survey_locale_group = current_user.account.survey_locale_groups.find_by(id: params[:survey_locale_group_id])
        render json: :forbidden, status: 404 and return
      end

      render partial: 'control/surveys/localization/new_base_question_modal', locals: { modal_id: params[:modal_id], survey_locale_group: survey_locale_group }
    end

    def update
      if @question.update(question_params)
        redirect_back fallback_location: root_path, notice: 'Question was successfully updated.'
      else
        redirect_back fallback_location: root_path, alert: @question.errors.full_messages.join(',')
      end
    end

    def text_responses
      @question = Question.find_by(id: params[:question_id], survey_id: current_user.account.surveys.pluck(:id))
      handle_missing_record and return unless @question

      filters = parse_filters(params)
      @presenter = FreeTextResponsePresenter.new(@question, autotag_enabled: current_user.account.tag_automation_enabled, filters: filters)

      render :text_responses
    end

    def update_tag
      @tag = @question.tags.find_by(id: params[:tag_id])
      handle_missing_record and return unless @tag

      if @tag.update(tag_params)
        render json: { id: @tag.id, text: @tag.name, color: @tag.color }
      else
        render json: [], status: :internal_server_error
      end
    end

    def create_tag
      @tag = @question.tags.new(color: params[:color], name: params[:name])

      if @tag.save
        render json: { id: @tag.id, text: @tag.name, color: @tag.color }
      else
        render json: [], status: :internal_server_error
      end
    end

    def delete_tag
      @tag = @question.tags.find_by(id: params[:tag_id])
      handle_missing_record and return unless @tag

      if @tag.destroy
        render json: { tagId: @tag.id }
      else
        render json: [], status: :internal_server_error
      end
    end

    def ai_tag_recommendations
      render json: { TagRecommendations: AITagRecommendation.request(question: @question) }
    end

    def toggle_tag_automation_worker
      @question.update(tag_automation_worker_enabled: params[:question][:tag_automation_worker_enabled])
    end

    def auto_tag_answers
      if tag_automation_job = @question.tag_automation_jobs.create(tag_automation_job_params)
        TagAutomationWorker.perform_async(tag_automation_job.id)
        render json: { tagAutomationJobId: tag_automation_job.id }, status: :ok
      else
        render json: [], status: :internal_server_error
      end
    end

    private

    def tag_automation_job_params
      params.require(:tag_automation_job).permit(tag_automation_job_answers_attributes: [:answer_id])
    end

    def create_possible_answers_for_localized_question(question)
      if question.nps
        Question::NUM_NPS_POSSIBLE_ANSWERS.times do |i|
          new_possible_answer_locale_group = PossibleAnswerLocaleGroup.create(name: i, owner_record_id: question.question_locale_group_id)
          new_possible_answer = PossibleAnswer.create(
            content: i,
            question_id: question.id,
            possible_answer_locale_group_id: new_possible_answer_locale_group.id
          )

          next if new_possible_answer.persisted?

          error_message = "Question: #{question.errors.full_messages.join(',')}"
          flash.alert = "Error saving: #{error_message}"
          raise ActiveRecord::Rollback
        end
      elsif question.slider_question? || question.multiple_choices_question? || question.single_choice_question?
        2.times do |i|
          new_possible_answer_locale_group = PossibleAnswerLocaleGroup.create(name: i, owner_record_id: question.question_locale_group_id)
          new_possible_answer = PossibleAnswer.create(
            content: "Answer #{i}",
            question_id: question.id,
            possible_answer_locale_group_id: new_possible_answer_locale_group.id
          )

          next if new_possible_answer.persisted?

          error_message = "Question: #{question.errors.full_messages.join(',')}"
          flash.alert = "Error saving: #{error_message}"
          raise ActiveRecord::Rollback
        end
      end
    end

    def set_question
      @question = Question.where(survey: current_account.surveys).find_by(id: params[:id])
      handle_missing_record unless @question
    end

    def set_survey_locale_group
      @survey_locale_group = current_user.account.survey_locale_groups.find_by(id: params[:survey_locale_group_id] || params[:survey][:survey_locale_group_id])

      redirect_to dashboard_path and return unless @survey_locale_group
    end

    def create_non_base_survey_question
      question_attributes = params[:survey][:question]["0"]

      question_locale_group = QuestionLocaleGroup.find(question_attributes[:question_locale_group_id])
      base_question = question_locale_group.base_question

      new_question = base_question.dup
      new_question.survey_id = question_attributes[:survey_id]
      new_question.content = question_attributes[:content]
      new_question.question_locale_group_id = question_locale_group.id

      new_question.free_text_next_question_id = nil # dup copies the ID from the base question
      new_question.next_question_id = nil # dup copies the ID from the base question

      render json: :internal_error, status: 500 and return unless new_question.save

      # There may be possible answers for this survey which were meant to route
      # to the question in the position we just added.
      # E.g. If the base survey had a possible answer routing to question3 and this
      # newly created question is this survey's question3, then we need to
      # update the possible answer to route to this question.
      new_question.survey.possible_answers.each(&:apply_locale_group_routing)

      # There may be questions for this survey which were meant to route
      # to the question in the position we just added.
      # E.g. If the base survey had a question routing to question3 and this
      # newly created question is this survey's question3, then we need to
      # update that question to route to this question.
      new_question.survey.questions.each(&:apply_locale_group_routing)

      render json: {}, status: :ok and return
    end

    # It's complex because of its transactional nature
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def base_survey_question
      error_message = ""

      # rubocop:disable Metrics/BlockLength
      ActiveRecord::Base.transaction do
        new_question_locale_group = QuestionLocaleGroup.create(owner_record_id: @survey_locale_group.id, name: params[:question_locale_group_name])

        if new_question_locale_group.persisted?
          nps_question = params[:question][:nps].present?
          base_survey = SurveyLocaleGroup.find_by(id: @survey_locale_group.id).base_survey

          next_question_id = if params[:next_question_locale_group_id].present?
            next_question_locale_group = QuestionLocaleGroup.find_by(id: params[:next_question_locale_group_id])
            next_question = next_question_locale_group.questions.find_by(survey_id: base_survey.id)
            next_question.id
          end

          new_question = Question.create(
            localization_question_params.merge(
              survey_id: base_survey.id,
              question_locale_group_id: new_question_locale_group.id,
              nps: nps_question,
              free_text_next_question_id: next_question_id,
              next_question_id: next_question_id,
              position: base_survey.questions.maximum(:position) + 1
            )
          )

          if new_question.persisted?
            create_possible_answers_for_localized_question(new_question)

            redirect_to localization_editor_path(@survey_locale_group.id), notice: "Question was successfully created."
          else
            error_message = "Question: #{new_question.errors.full_messages.join(',')}"
            raise ActiveRecord::Rollback
          end
        else
          error_message = "QuestionLocaleGroup: #{new_question_locale_group.errors.full_messages.join(',')}"
        end
      end

      return if error_message.blank?

      redirect_to localization_editor_path(@survey_locale_group.id), alert: "Error saving: #{error_message}"
    end

    def localization_question_params
      params[:question][:question_type] = params[:question][:question_type].to_i
      accepted_question_params = [:content, :question_type, :randomize, :enable_maximum_selection, :maximum_selection, :hint_text, :submit_label]

      # A bit of a mess because a set of fields that would normally be in the :question hash are instead
      # provided in a sub-hash. We're stuck with this because we're trying to reuse the individual survey edit page's
      # partial without affecting the individual survey edit page.
      question_type_params = params[:question].delete(:additional_question_fields)
      vetted_params = params.require(:question).permit(accepted_question_params)

      if question_type_params
        accepted_question_type_params = [
          :button_type, :desktop_width_type, :answers_per_row_desktop, :answers_alignment_desktop, :mobile_width_type, :answers_per_row_mobile,
          :answers_alignment_mobile, :before_question_text, :after_question_text, :before_answers_count, :before_answers_items,
          :after_answers_count, :after_answers_items, :height, :max_length, :fullscreen, :background_color, :opacity,
          :autoclose_enabled, :autoclose_delay, :autoredirect_enabled, :autoredirect_url, :autoredirect_delay
        ]
        vetted_question_type_params = question_type_params.permit(accepted_question_type_params)

        vetted_params.merge!(vetted_question_type_params)
      end

      vetted_params
    end

    def tag_params
      params.require(:tag).permit(:name, :color)
    end

    def question_params
      params.require(:question).permit(:id, :survey_id, :custom_content)
    end

    def require_full_access_user!
      if !user_signed_in?
        flash.alert = 'You need to be logged in to access this page.'
        redirect_to sign_in_url
        return false
      elsif !current_user.full?
        flash.alert = 'Unauthorized!'
        redirect_to dashboard_url
        return false
      end
    rescue ActiveRecord::RecordNotFound
      # Happens if a logged in user gets deleted from the database
      redirect_to sign_in_url
      return false
    end

    def require_tag_automation
      render json: :forbidden, status: 403 and return unless current_account.tag_automation_enabled
    end
  end
end
