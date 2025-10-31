# frozen_string_literal: true

# This worker updates specific fields in the dataset according to changes in the metadata every 5 minutes
# This worker is not hooked to model callbacks like FullDeleteWorker because the "tags" field might overflow the queue due to the Bulk/Auto Tagging feature
module Qrvey
  class PartialUpdateWorker
    include Sidekiq::Worker
    include Common
    include Qrvey::Dataset

    BATCH_SIZE = 25000 # Benchmarking: https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2537#note_1081050

    def perform(custom_start_time: nil, custom_end_time: nil)
      # Rounding seconds not to skip any audits
      @start_time = custom_start_time || 5.minute.ago.beginning_of_minute
      @end_time = custom_end_time || Time.current.beginning_of_minute
      tagged_logger.info "start_time: #{@start_time}, end_time: #{@end_time}"

      metadata_audits.map do |audit|
        tagged_logger.info "Audit ID: #{audit.id}"

        # Fields for which the modifications extend to the audit's associations
        update_next_question_field(audit)
        update_next_question_base_field(audit)
        update_survey_base_field(audit)
        update_question_base_field(audit)
        update_response_base_field(audit)

        # Fields where the scope of modifications can differ under certain conditions
        update_next_question_fields_for_multi_choice(audit)

        # Fields made of multiple columns
        update_sort_id_fields_for_question(audit)
        update_sort_id_fields_for_possible_answer(audit)

        # Fields which exclusively modify dataset rows associated with the audit while sharing the identical value to update within that audit
        update_common_fields(audit)
      end

      # Fields that are dependant on audits not exclusive to the 'update' type
      update_tags_field
      update_survey_tags_field
    rescue => e
      Rollbar.error e
      tagged_logger.error e
    end

    def update_next_question_field(audit)
      return if audit.auditable_type != 'Question'
      return if audit.audited_changes['content'].blank?

      previous_questions = Question.where(next_question_id: audit.auditable_id)
      return unless previous_questions.exists?

      answer_scope = Answer.select(:id).where(question: previous_questions)
      target_fields = { next_question: audit.auditable.content }
      update_fields(answer_scope: answer_scope, target_fields: target_fields)
    end

    def update_next_question_base_field(audit)
      return if audit.auditable_type != 'Question'
      return if audit.audited_changes['content'].blank?

      question = audit.auditable
      return unless question.base_question?

      previous_questions = Question.where(next_question_id: question.question_locale_group.questions.ids)
      return unless previous_questions.exists?

      answer_scope = Answer.select(:id).where(question: previous_questions)
      target_fields = { next_question_base: question.content }
      update_fields(answer_scope: answer_scope, target_fields: target_fields)
    end

    def update_survey_base_field(audit)
      return if audit.auditable_type != 'Survey'
      return if audit.audited_changes['name'].blank?

      survey = audit.auditable
      return unless survey.base_survey?

      answers = Answer.select(:id).joins(:submission).where(submission: { survey: survey.survey_locale_group.surveys })
      target_fields = { survey_base: survey.name }
      update_fields(answer_scope: answers, target_fields: target_fields)
    end

    def update_question_base_field(audit)
      return if audit.auditable_type != 'Question'
      return if audit.audited_changes['content'].blank?

      question = audit.auditable
      return unless question.base_question?

      answer_scope = Answer.select(:id).where(question: question.question_locale_group.questions)
      target_fields = { question_base: question.content }
      update_fields(answer_scope: answer_scope, target_fields: target_fields)
    end

    def update_response_base_field(audit)
      return if audit.auditable_type != 'PossibleAnswer'
      return if audit.audited_changes['content'].blank?

      possible_answer = audit.auditable
      return unless possible_answer.base_possible_answer?

      answer_scope = Answer.select(:id).where(possible_answer: possible_answer.possible_answer_locale_group.possible_answers)
      target_fields = { response_base: possible_answer.content }
      update_fields(answer_scope: answer_scope, target_fields: target_fields)
    end

    def update_next_question_fields_for_multi_choice(audit)
      return if audit.auditable_type != 'Question'
      return if audit.audited_changes['next_question_id'].blank?

      question = audit.auditable
      return unless question.multiple_choices_question?

      # Filter out answers whose next question come from the last possible answer
      last_possible_answer = question.possible_answers.sort_by_position.last
      answer_scope = question.answers
      answer_scope = answer_scope.where.not(possible_answer: last_possible_answer) if last_possible_answer.next_question.present?

      target_fields = { next_question_id: question.next_question_id }
      if next_question_locale_group = question.next_question&.question_locale_group.presence
        target_fields[:next_question_id_canonical] = next_question_locale_group.id
        target_fields[:next_question_canonical] = next_question_locale_group.name # The field mapper handles changes to the group name
        target_fields[:next_question_base] = next_question_locale_group.base_question.content # An update method handles changes to the question content
      end

      update_fields(answer_scope: answer_scope, target_fields: target_fields)
    end

    def update_tags_field
      tag_audits = CustomAudit.where(auditable_type: 'Tag', action: 'update', created_at: @start_time..@end_time).with_attribute('name')
      applied_tag_audits = CustomAudit.where(auditable_type: 'AppliedTag', action: %w(create destroy), created_at: @start_time..@end_time)

      answer_scope = Answer.where(id: AppliedTag.where(tag_id: tag_audits.pluck(:auditable_id)).pluck(:answer_id))
      answer_scope = answer_scope.or(Answer.where(id: applied_tag_audits.pluck(:audited_changes).map { |audited_changes| audited_changes['answer_id'] }))

      update_fields(answer_scope: answer_scope.includes(:tags)) do |answer|
        target_fields = { tags: answer.tags.order(:id).pluck(:name).join('; ') }
        unique_id_field(answer).merge(target_fields)
      end
    end

    def update_survey_tags_field
      survey_tag_audits = CustomAudit.where(auditable_type: 'SurveyTag', action: 'update', created_at: @start_time..@end_time).with_attribute('name')
      applied_survey_tag_audits = CustomAudit.where(auditable_type: 'AppliedSurveyTag', action: %w(create destroy), created_at: @start_time..@end_time)

      surveys = Survey.where(id: AppliedSurveyTag.where(survey_tag_id: survey_tag_audits.pluck(:auditable_id)).pluck(:survey_tag_id))
      surveys = surveys.or(Survey.where(id: applied_survey_tag_audits.pluck(:audited_changes).map { |audited_changes| audited_changes['survey_id'] }))

      surveys.includes(:survey_tags).each do |survey|
        tagged_logger.info "Survey ID: #{survey.id}"

        survey_tag_names = survey.survey_tags.order(:id).pluck(:name).join('; ')

        answer_scope = Answer.select(:id).joins(:submission).where(submission: { survey: survey })
        target_fields = { survey_tags: survey_tag_names, survey_tag_staging: survey_tag_names.include?('staging') ? 'staging' : nil }.compact
        update_fields(answer_scope: answer_scope, target_fields: target_fields)
      end
    end

    def update_sort_id_fields_for_question(audit)
      return if audit.auditable_type != 'Question'
      return if audit.audited_changes['position'].blank?

      question = audit.auditable
      answer_scope = Answer.where(question: question)
      update_fields(answer_scope: answer_scope) { |answer| unique_id_field(answer).merge sort_id_fields(question, answer.possible_answer) }
    end

    def update_sort_id_fields_for_possible_answer(audit)
      return if audit.auditable_type != 'PossibleAnswer'
      return if audit.audited_changes['position'].blank?

      possible_answer = audit.auditable
      answer_scope = Answer.where(possible_answer: possible_answer)
      update_fields(answer_scope: answer_scope, target_fields: sort_id_fields(possible_answer.question, possible_answer))
    end

    def update_common_fields(audit)
      target_fields = common_fields(audit).merge(annex_fields(audit), updated_at_field(audit))
      update_fields(answer_scope: audit.auditable.answers.select(:id), target_fields: target_fields)
    end

    # This method constructs a payload, transmits it to the API, and records the time taken
    #
    #   @answer_scope:  Answers requiring synchronization
    #   @target_fields: Combinations of field names and corresponding updated values
    #   @update_generation: A block for customizing payload creation
    def update_fields(answer_scope:, target_fields: nil, &update_generation)
      tagged_logger.info 'No field found' and return unless target_fields || update_generation

      tagged_logger.info "Fields to update: #{target_fields.keys}" if target_fields

      start_time = Time.current

      answer_scope.order(:id).find_in_batches(batch_size: BATCH_SIZE).with_index do |batch, index| # ORDER is for testing
        tagged_logger.info "#{index.ordinalize} batch, #{batch.count} records"

        updates = block_given? ? batch.map(&update_generation) : batch.map { |answer| unique_id_field(answer).merge(target_fields) }

        send_to_push_api(updates)
      end

      tagged_logger.info "Duration: #{(Time.current - start_time).to_i} seconds"
    end

    # Filtering out non-metadata tables
    # Not Filtering out non-metadata columns because "updated_at" is updated regardless of which column has been updated
    def metadata_audits
      audits = CustomAudit.where(auditable_type: METADATA_AUDIT_TYPES, action: 'update', created_at: @start_time..@end_time).order(:id)
      tagged_logger.info "#{audits.count} audits found"
      audits
    end

    def send_to_push_api(updates)
      return unless %w(production staging develop).include? Rails.env

      Retryable.with_retry(interval: 60) do
        RestClient::Request.execute(method: :post, url: push_api_endpoint, payload: payload(updates), headers: headers, log: tagged_logger)
      end
    end

    def push_api_endpoint
      'https://z8ugi4itmh.execute-api.us-east-1.amazonaws.com/Prod/dataload/postdata'
    end

    def headers
      { 'x-api-key': Rails.application.credentials[:qrvey][:api_key], 'content_type': 'application/json' }
    end

    def payload(data)
      { datasetId: Rails.configuration.qrvey_dataset_id, documentUpdateMethod: 'upsert', data: data }.to_json
    end
  end
end
