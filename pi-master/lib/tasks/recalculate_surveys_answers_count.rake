# frozen_string_literal: true

task recalculate_surveys_answers_count: :environment do
  Survey.all.each do |survey|
    new_answers_count = survey.submissions.count

    puts "Updating survey #{survey.id} - Old answers_count: #{survey.answers_count} - New answers_count: #{new_answers_count}"

    survey.update(answers_count: new_answers_count)
  end
end
