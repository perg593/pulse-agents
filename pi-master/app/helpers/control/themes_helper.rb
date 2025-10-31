# frozen_string_literal: true
module Control
  module ThemesHelper
    def theme_used_by_links(theme)
      theme.surveys.map do |survey|
        link_to(survey.name, edit_survey_path(survey))
      end.join(', ').html_safe
    end
  end
end
