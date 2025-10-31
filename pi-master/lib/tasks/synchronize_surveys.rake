# frozen_string_literal: true

desc <<~DESC
  E.g. rake dump_survey[1000,/tmp/survey.json]'

  TODO: Copy other associations like locale_groups, themes, and other types of triggers
  TODO: Take advantage of accepts_nested_attributes_for
DESC
task :dump_survey, [:survey_id, :output_filename] => :environment do |_task, arguments|
  survey_json = Survey.find(arguments[:survey_id].to_i).as_json(
    except: %i(id created_at updated_at),
    include: {
      questions: {
        except: %i(id created_at updated_at survey_id),
        include: {
          possible_answers: {
            except: %i(id created_at updated_at question_id)
          }
        }
      },
      triggers: {
        except: %i(id created_at updated_at survey_id previous_answered_survey_id previous_possible_answer_id),
        methods: :type_cd # Inheritance column
      }
    }
  )

  survey_json['status'] = 'draft'

  File.write(arguments[:output_filename], survey_json.to_json)
end

desc <<~DESC
  E.g. rake restore_survey[/tmp/survey.json]'

  TODO: Validate account with fallback to Adam
DESC
task :restore_survey, %i(input_filename) => :environment do |_task, arguments|
  survey_attributes = JSON.parse(File.read(arguments[:input_filename]))
  survey = Survey.create!(survey_attributes.except('questions', 'triggers'))

  survey_attributes['questions'].each do |question_attributes|
    question = Question.create!(survey_id: survey.id, **question_attributes.except('possible_answers'))

    question_attributes['possible_answers'].each do |possible_answer_attributes|
      PossibleAnswer.create!(question_id: question.id, **possible_answer_attributes)
    end
  end

  survey_attributes['triggers'].each do |trigger_attributes|
    Trigger.create!(survey_id: survey.id, **trigger_attributes)
  end
end
