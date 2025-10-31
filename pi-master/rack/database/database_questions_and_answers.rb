# rubocop:disable Metrics/ModuleLength, Metrics/AbcSize

# frozen_string_literal: true

module Rack
  module DatabaseQuestionsAndAnswers
    # Please update app/models/question.rb when you update this constant
    QUESTION_TYPES = { single_choice_question: 0, free_text_question: 1, custom_content_question: 2, multiple_choices_question: 3, slider_question: 4 }.freeze

    def get_question_by_id(id, survey_id, pi_identifier)
      sql = <<-SQL
        SELECT "questions"."id", "questions"."question_type", "questions"."content", "questions"."question_locale_group_id"
        FROM "questions"
        INNER JOIN "surveys" ON "surveys"."id" = "questions"."survey_id"
        INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
        WHERE "accounts"."identifier" = '#{PG::Connection.escape(pi_identifier)}' AND "questions"."id" = #{PG::Connection.escape(id.to_s).to_i} AND "surveys"."id" = #{PG::Connection.escape(survey_id.to_s).to_i}
      SQL

      log sql, 'DEBUG'

      postgres_execute(sql).first
    end

    def get_first_question(survey_id, pi_identifier)
      sql = <<-SQL
        SELECT "questions"."id", "questions"."question_type", "questions"."content", "questions"."question_locale_group_id"
        FROM "surveys"
        INNER JOIN "questions" ON "surveys"."id" = "questions"."survey_id"
        INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
        WHERE "accounts"."identifier" = '#{PG::Connection.escape(pi_identifier)}' AND "surveys"."id" = #{PG::Connection.escape(survey_id.to_s).to_i}
        ORDER BY "questions"."position" ASC
        LIMIT 1
      SQL

      log sql, 'DEBUG'

      postgres_execute(sql).first
    end

    # Get survey questions and possible answers
    def load_survey_questions_and_possible_answers(pi_identifier, id)
      #
      # Looking up both by account identifier and survey id seems redundant, but want to avoid people passing random ids
      #  to get surveys content.
      #
      sql = <<-SQL
        SELECT "questions"."id" AS question_id, "questions"."question_type", "questions"."hint_text", "questions"."error_text", "questions"."empty_error_text", "questions"."submit_label", "questions"."height", "questions"."max_length",
          "questions"."free_text_next_question_id", "questions"."position", "questions"."content" AS question_content, "questions"."randomize", "possible_answers"."id" AS possible_answers_id,
          "possible_answers"."content" AS possible_answer_content, "possible_answers"."next_question_id" AS possible_answers_next_question_id, "questions"."custom_content", "questions"."fullscreen", "questions"."background_color",
          "questions"."opacity", "questions"."autoclose_enabled", "questions"."autoclose_delay", "questions"."autoredirect_enabled", "questions"."autoredirect_delay", "questions"."show_after_aao", "questions"."single_choice_default_label",
          "questions"."autoredirect_url", "questions"."enable_maximum_selection", "questions"."maximum_selection", "questions"."maximum_selections_exceeded_error_text", "questions"."next_question_id" AS questions_next_question_id,
          "questions"."button_type", "questions"."desktop_width_type", "questions"."answers_alignment_desktop", "questions"."answers_per_row_desktop",
          "questions"."answers_per_row_mobile", "questions"."optional", "questions"."image_settings", "answer_images"."id" AS answer_image_id,
          "answer_images"."image", "possible_answers"."image_alt", "possible_answers"."image_width", "possible_answers"."image_height", "possible_answers"."position" AS possible_answer_position,
          "possible_answers"."image_width_mobile", "possible_answers"."image_height_mobile", "possible_answers"."image_width_tablet",
          "possible_answers"."image_height_tablet", "possible_answers"."image_position_cd", "questions"."mobile_width_type",
          "questions"."answers_alignment_mobile", "questions"."created_at", "questions"."additional_text"->>'before_question_text' AS before_question_text,
          "questions"."additional_text"->>'after_question_text' AS after_question_text, "questions"."additional_text"->>'before_answers_count' AS before_answers_count,
          "questions"."additional_text"->>'after_answers_count' AS after_answers_count, "questions"."additional_text"->>'before_answers_items' AS before_answers_items,
          "questions"."additional_text"->>'after_answers_items' AS after_answers_items, "questions"."nps", "questions"."question_locale_group_id", "possible_answers"."possible_answer_locale_group_id",
          "questions"."show_additional_content", "questions"."additional_content", "questions"."additional_content_position", "questions"."slider_start_position", "questions"."slider_submit_button_enabled"
        FROM "questions"
        INNER JOIN "surveys" ON "surveys"."id" = "questions"."survey_id"
        INNER JOIN "accounts" ON "accounts"."id" = "surveys"."account_id"
        LEFT OUTER JOIN "possible_answers" ON "possible_answers"."question_id" = "questions"."id"
        LEFT OUTER JOIN "answer_images" ON "possible_answers"."answer_image_id" = "answer_images"."id"
        WHERE "accounts"."identifier" = '#{PG::Connection.escape(pi_identifier)}' AND "surveys"."id" = #{PG::Connection.escape(id.to_s).to_i}
        ORDER BY "questions"."position", "possible_answers"."position";
      SQL
      log sql, 'DEBUG'
      questions = {}

      postgres_execute(sql).each do |row|
        questions = process_each_question(questions, row)
      end

      questions.values.sort { |a, b| a[:position] <=> b[:position] }
    end

    # Supplements a question hash with possible answer specific attributes
    def process_each_question(questions, row)
      id = row["question_id"].to_i
      questions[id] = process_new_question(row) if questions[id].nil?

      # The other question types don't have possible answers
      return questions unless %i(single_choice_question multiple_choices_question slider_question).include? questions[id][:question_type]

      questions[id][:possible_answers] ||= []
      questions[id][:possible_answers] << {
        id: row["possible_answers_id"].to_i,
        position: row["possible_answer_position"].to_i,
        content: row["possible_answer_content"],
        next_question_id: (row["possible_answers_next_question_id"].nil? ? nil : row["possible_answers_next_question_id"].to_i),
        image_url: image_url(row["answer_image_id"], row["image"]),
        image_alt: row["image_alt"],
        image_width: row["image_width"],
        image_height: row["image_height"],
        image_width_mobile: row["image_width_mobile"],
        image_height_mobile: row["image_height_mobile"],
        image_width_tablet: row["image_width_tablet"],
        image_height_tablet: row["image_height_tablet"],
        image_position: row["image_position_cd"],
        possible_answer_locale_group_id: row["possible_answer_locale_group_id"]
      }

      # If the randomize option is selected, shuffle the possible answers
      # If the 'randomize all except last' option is selected:
      # Shuffle from 0 to -2 then push the last one (-1) then call 'compact' in case possible_answers was empty
      case row["randomize"]
      when '0'
        questions[id][:possible_answers] = questions[id][:possible_answers].shuffle
      when '1'
        questions[id][:possible_answers] = questions[id][:possible_answers][0..-2].shuffle.push(questions[id][:possible_answers][-1]).compact
      end

      questions
    end

    def image_url(image_id, image_name)
      return unless image_id

      "https://cdn.pulseinsights.com/images/answer_image/#{image_id}/#{image_name}"
    end

    # TODO: Fill in empty db values with "Select an option" and remove this.
    def single_choice_default_label(question)
      return 'Select an option' if question["single_choice_default_label"].nil? || question["single_choice_default_label"].empty?
      question["single_choice_default_label"]
    end

    # TODO: Fill in empty db values with "Oops, looks like you are trying to submit personal information!" and remove this.
    def error_text(question)
      return 'Oops, looks like you are trying to submit personal information!' if question["error_text"].nil? || question["error_text"].empty?
      question["error_text"]
    end

    # TODO: Fill in empty db values with "Required." and remove this.
    def empty_error_text(question)
      return 'Required.' if question["empty_error_text"].nil? || question["empty_error_text"].empty?
      question["empty_error_text"]
    end

    # Supplements a question hash with question type specific attributes
    def process_new_question(question)
      question_type = QUESTION_TYPES.key(question["question_type"].to_i)
      result = next_question_hash(question, question_type)

      case question_type
      when :multiple_choices_question
        result[:maximum_selection] = question["maximum_selection"].to_i if question["enable_maximum_selection"] == 't'
        result[:maximum_selections_exceeded_error_text] = question["maximum_selections_exceeded_error_text"] if question["enable_maximum_selection"] == 't'
        result[:next_question_id] = question["questions_next_question_id"].to_i
      when :free_text_question
        result.merge!(hint_text: question["hint_text"], error_text: error_text(question),
                      submit_label: question["submit_label"], height: question["height"].to_i, max_length: question["max_length"].to_i,
                      next_question_id: question["free_text_next_question_id"].to_i)
      when :custom_content_question
        result.merge!(content: question["custom_content"], fullscreen: question["fullscreen"],
                      background_color: question["background_color"], opacity: question["opacity"],
                      autoclose_enabled: question["autoclose_enabled"], autoclose_delay: question["autoclose_delay"],
                      show_after_aao: question["show_after_aao"] == 't',
                      autoredirect_enabled: question["autoredirect_enabled"],
                      autoredirect_delay: question["autoredirect_delay"], autoredirect_url: question["autoredirect_url"])
      when :slider_question
        result[:slider_start_position] = question['slider_start_position']
        result[:slider_submit_button_enabled] = question['slider_submit_button_enabled']
      end

      result
    end

    # Returns a hash containing attributes shared by all question types
    # rubocop:disable Metrics/MethodLength -- Questions have a lot of properties
    def next_question_hash(question, question_type)
      question_hash = {
        id: question["question_id"].to_i, question_type: question_type,
        position: question["position"].to_i,
        content: question["question_content"],
        submit_label: question["submit_label"],
        button_type: question["button_type"]&.to_i,
        desktop_width_type: question["desktop_width_type"]&.to_i,
        answers_alignment_desktop: question["answers_alignment_desktop"]&.to_i,
        answers_per_row_desktop: question["answers_per_row_desktop"]&.to_i,
        answers_per_row_mobile: question["answers_per_row_mobile"]&.to_i,
        optional: question["optional"],
        image_type: question["image_settings"],
        mobile_width_type: question["mobile_width_type"]&.to_i,
        answers_alignment_mobile: question["answers_alignment_mobile"]&.to_i,
        created_at: Time.parse(question["created_at"]).to_i,
        before_question_text: question["before_question_text"],
        after_question_text: question["after_question_text"],
        before_answers_count: question["before_answers_count"],
        after_answers_count: question["after_answers_count"],
        before_answers_items: question["before_answers_items"],
        after_answers_items: question["after_answers_items"],
        nps: question["nps"],
        single_choice_default_label: single_choice_default_label(question),
        question_locale_group_id: question["question_locale_group_id"],
        additional_content: question["additional_content"],
        additional_content_position: question["additional_content_position"].to_i,
        empty_error_text: empty_error_text(question)
      }

      if question["show_additional_content"] == "f"
        question_hash.delete(:additional_content)
        question_hash.delete(:additional_content_position)
      end

      question_hash
    end
  end
end
