# frozen_string_literal: true

module Qrvey
  module Dataset
    UNIQUE_ID_KEY = :answer_id

    METADATA_AUDIT_TYPES = %w(Account Survey Question PossibleAnswer LocaleGroup).freeze

    COMMON_FIELD_MAP = {
      Account: {
        updated_at: :account_updated, name: :account_name, enabled: :account_enabled, is_observed: :account_is_observed,
        frequency_cap_enabled: :account_freq_cap_enabled, frequency_cap_limit: :account_freq_cap_limit, frequency_cap_duration: :account_freq_cap_duration,
        frequency_cap_type: :account_freq_cap_type, ip_storage_policy: :account_ip_storage_policy,
        custom_content_link_click_enabled: :account_custom_content_link_click_enabled, tag_automation_enabled: :account_tag_automation_enabled
      },
      Survey: {
        name: :survey_name, updated_at: :survey_updated, starts_at: :survey_starts, ends_at: :survey_ends, live_at: :survey_live, goal: :survey_goal,
        sample_rate: :survey_sample_rate, invitation: :survey_invitation, thank_you: :survey_thank_you, language_code: :survey_language_code,
        desktop_enabled: :survey_desktop_enabled, tablet_enabled: :survey_tablet_enabled, randomize_question_order: :survey_randomize_question_order,
        mobile_enabled: :survey_mobile_enabled, ios_enabled: :survey_ios_enabled, android_enabled: :survey_android_enabled, status: :survey_status,
        email_enabled: :survey_email_enabled, poll_enabled: :survey_poll_enabled, display_all_questions: :survey_all_at_once, survey_type: :survey_type,
        stop_showing_without_answer: :survey_stop_showing_without_answer, ignore_frequency_cap: :survey_ignore_frequency_cap, locale_code: :survey_locale_code
      },
      Question: { content: :question, updated_at: :question_updated, position: :question_position, free_text_next_question_id: :next_question_id },
      PossibleAnswer: { updated_at: :possible_answer_updated, position: :possible_answer_position, next_question_id: :next_question_id, content: :response },
      SurveyLocaleGroup: { name: :survey_canonical, updated_at: :survey_canonical_updated },
      QuestionLocaleGroup: { name: :question_canonical, updated_at: :question_canonical_updated },
      PossibleAnswerLocaleGroup: { name: :response_canonical, updated_at: :possible_answer_canonical_updated }
    }.deep_stringify_keys.freeze

    def unique_id_field(answer)
      { UNIQUE_ID_KEY => answer.id }
    end

    # Removing unnecessary keys, transforming keys, and adding extra keys
    def common_fields(audit)
      auditable = audit.auditable
      auditable_class = auditable.class.to_s # auditable_type returns the closest model to ActiveRecord::Base (E.g. SurveyLocaleGroup -> LocaleGroup)
      audited_changes = audit.audited_changes

      common_field_map = COMMON_FIELD_MAP[auditable_class]                        # Field mapper for a specific table
      latest_audited_changes = auditable.attributes.slice(*audited_changes.keys)  # Fetching the most recent values with job retries in mind
      fields = latest_audited_changes.slice(*common_field_map.keys)               # Removing unnecessary keys
      fields.transform_keys(common_field_map)                                     # Transforming keys
    end

    # Common fields that require customized generation
    def annex_fields(audit)
      auditable = audit.auditable
      audited_changes = audit.audited_changes

      fields = {}
      case auditable
      when Survey
        fields[:survey_status_id] = Survey.statuses[auditable.status] if audited_changes['status'].present?
        fields[:survey_type_id] = Survey.survey_types[auditable.survey_type] if audited_changes['survey_type'].present?
      when PossibleAnswer
        fields[:possible_answer] = auditable.content if audited_changes['content'].present? # Please refer to qrvey.sql.erb as to why this field exists
      end
      fields
    end

    def updated_at_field(audit)
      { COMMON_FIELD_MAP[audit.auditable.class.to_s]['updated_at'] => audit.auditable.updated_at }
    end

    def sort_id_fields(question, possible_answer)
      question_position = question.position.to_s.rjust(3, '0')
      possible_answer_position = possible_answer&.position.to_s.rjust(3, '0') # Will be '000' for free text questions

      survey_id = question.survey_id
      survey_locale_group_id = question.survey.survey_locale_group_id || '000'

      sort_id = "#{survey_id}.#{question_position}#{possible_answer_position}"
      sort_group_id = "#{survey_locale_group_id}.#{question_position}#{possible_answer_position}"

      { sort_id: sort_id, sort_group_id: sort_group_id }
    end
  end
end
