# TODO Narrow the scope
$(document).ready ->
  return unless $('select#applied_survey_tags').length > 0

  $('select#applied_survey_tags').select2(tags: true)

  selected_values = $('.survey_applied_survey_tags').data('selected-value')
  $('select#applied_survey_tags').val(selected_values).trigger('change');
