# frozen_string_literal: true

task attach_survey_stats: :environment do
  Survey.all.each do |survey|
    next if survey.survey_stat

    SurveyStat.create(survey: survey, answers_count: survey.answers_count)
  end
end
