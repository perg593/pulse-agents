# Client-side integration
#
# Used as:
#  pi('oncomplete', function(survey) {});
#
window.PulseInsightsInclude window.PulseInsights,
  onclose: (callbackFunction) ->
    @log "Onclose Callback function disabled."

  oncomplete: (callbackFunction) ->
    @log "Oncomplete Callback function disabled."

  onanswer: (callbackFunction) ->
    @log "Onanswer Callback function disabled."

  onimpression: (callbackFunction) ->
    @log "Onimpression Callback function disabled."

  onview: (callbackFunction) ->
    @log "Onview Callback function disabled."

  onclick: (callbackFunction) ->
    @log "Onclick Callback function disabled."

  triggerOnCloseCallback: ->
    @log "Callback is not supported in surveys-ncb.js"
    @survey.onclose_callback_executed = true

  triggerOnCompleteCallback: ->
    @log "Callback is not supported in surveys-ncb.js"
    @survey.oncomplete_callback_executed = true

  triggerOnAnswerCallback: ->
    @log "Callback is not supported in surveys-ncb.js"

  triggerOnImpressionCallback: ->
    @log "Callback is not supported in surveys-ncb.js"

  triggerOnViewCallback: ->
    @log "Callback is not supported in surveys-ncb.js"
    @survey.onview_callback_executed = true

  triggerOnClickCallback: ->
    @log "Callback is not supported in surveys-ncb.js"
