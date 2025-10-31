# frozen_string_literal: true

module Rack
  module Database
    module PDFTemplates
      module Database
        def question_type_label_conversion_sql
          <<-SQL
            CASE WHEN questions.question_type = '0' THEN 'single_choice_question'
                 WHEN questions.question_type = '1' THEN 'free_text_question'
                 WHEN questions.question_type = '2' THEN 'custom_content_question'
                 WHEN questions.question_type = '3' THEN 'multiple_choices_question'
                 WHEN questions.question_type = '4' THEN 'slider_question'
            END AS question_type
          SQL
        end

        def get_survey_pdf_template_object_keys(survey_id)
          sql = <<-SQL
            SELECT pdf_template_file_uploads.object_key FROM pdf_template_file_uploads
            INNER JOIN metadata ON metadata.id = pdf_template_file_uploads.metadatum_id AND metadata.type = 'Metadata::SurveyMetadatum'
            INNER JOIN surveys survey ON survey.id = metadata.owner_record_id
            WHERE survey.id = #{survey_id}
          SQL

          log sql, "DEBUG"

          result = postgres_execute(sql)

          return nil if result == false

          result.field_values("object_key")
        end

        def get_survey_pdf_template_metadata(object_key)
          sql = <<-SQL
            SELECT pdf_template_file_uploads.metadata FROM pdf_template_file_uploads
            WHERE pdf_template_file_uploads.object_key = '#{object_key}'
          SQL

          log sql, "DEBUG"

          result = postgres_execute(sql)

          return nil if result == false

          JSON.parse(result.first["metadata"])
        end

        def get_template_submission(survey_id)
          question_rows = retrieve_template_submission_data(survey_id)
          transform_template_submission_rows(question_rows)
        end

        private

        def retrieve_template_submission_data(survey_id)
          sql = <<-SQL
            SELECT questions.id AS question_id, questions.content AS question_content, questions_metadatum.name AS question_metaname, questions.position AS question_position,
            possible_answers.id AS possible_answer_id, possible_answers.content AS possible_answer_content, possible_answers_metadatum.name AS possible_answer_metaname, possible_answers.position AS possible_answer_position,
            #{question_type_label_conversion_sql}
            FROM surveys
            JOIN questions ON questions.survey_id = surveys.id
            JOIN possible_answers ON possible_answers.question_id = questions.id
            JOIN metadata AS questions_metadatum ON questions_metadatum.owner_record_id = questions.id AND questions_metadatum.type = 'Metadata::QuestionMetadatum'
            JOIN metadata AS possible_answers_metadatum ON possible_answers_metadatum.owner_record_id = possible_answers.id AND possible_answers_metadatum.type = 'Metadata::PossibleAnswerMetadatum'
            WHERE surveys.id = '#{PG::Connection.escape(survey_id)}'
            ORDER BY questions.position, possible_answers.position
          SQL
          log sql, 'DEBUG'

          postgres_execute(sql)
        end

        def transform_template_submission_rows(question_rows)
          return unless question_rows

          {
            questions: question_rows.group_by { |row| row["question_id"] }.map do |question_id, question_possible_answer_rows|
              {
                id: question_id.to_i,
                type: question_possible_answer_rows.first["question_type"],
                content: question_possible_answer_rows.first["question_content"],
                metaname: question_possible_answer_rows.first["question_metaname"],
                possible_answers: question_possible_answer_rows.map do |possible_answer_row|
                  {
                    id: possible_answer_row["possible_answer_id"].to_i,
                    content: possible_answer_row["possible_answer_content"],
                    metaname: possible_answer_row["possible_answer_metaname"]
                  }
                end
              }
            end
          }
        end
      end
    end
  end
end
