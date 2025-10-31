# Present survey
#
# Used as:
#  pi('present', <survey id>);
#
window.PulseInsightsInclude window.PulseInsights,
  present: (surveyIdOrEventName, override) ->
    @override = override
    this.jsonpGet "/surveys/#{surveyIdOrEventName}", this.collectEnvironmentAttributes(surveyIdOrEventName), this.surveyLoaded

  surveyLoaded: (data) ->
    if @override
      for key of @override
        data.survey[key] = @override[key] if @override.hasOwnProperty(key)

    this.log "Survey loaded"
    if data.device?
      @udid = data.device.udid
      this.updateUDID(@udid)
    if data.device_data?
      @device_data = data.device_data
    if data.survey?
      @submission = data.submission
      this.log "Rendering survey #{data.survey.id}"
      this.renderSurvey(data.survey)
    else
      this.log "No survey to render"
  extend = (obj, src) ->
    for key of src
      if src.hasOwnProperty(key)
        obj[key] = src[key]
    obj
