# Present survey
#
# Used as:
#  pi('present_poll', <survey id>, <question_id>);
#
window.PulseInsightsInclude window.PulseInsights,
  present_poll: (surveyId, questionId) ->
    this.jsonpGet "/surveys/#{surveyId}/poll", this.pollParams(questionId), this.pollLoaded

  pollLoaded: (data) ->
    this.log "Survey loaded"

    if data.survey? && data.results? && data.results.length > 0
      @poll = data.results
      @question = data.question
      this.log "Rendering survey #{data.survey.id} and poll"
      this.renderSurvey(data.survey)
    else
      this.log "No survey to render"

  pollParams: (questionId) ->
    params = this.collectEnvironmentAttributes()
    params['question_id'] = questionId
    params

