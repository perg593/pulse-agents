window.PulseInsightsInclude window.PulseInsights,
  executeCustomDataSnippet: (survey) ->
    this.log "Executing Custom Data Snippet."
    this.log "This function is deprecated. Please use 'onimpression' instead."
    window.PulseInsightsObject.triggerOnImpressionCallback()
