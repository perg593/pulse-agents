# Custom Content Link Click - Log clicking of any links inside custom content
#
window.PulseInsightsInclude window.PulseInsights,
  logCustomContentLinkClick: (questionId, linkIdentifier) ->
    this.jsonpGet "/custom_content_link_click", this.customContentLinkClickParameters(questionId, linkIdentifier), this.customContentLinkClickCallback

  customContentLinkClickParameters: (questionId, linkIdentifier) ->
    submission_udid: this.submission.udid
    question_id: questionId
    link_identifier: linkIdentifier
    client_key: this.getClientKey()
    custom_data: window.PulseInsightsObject.stringify(this.customData)

  customContentLinkClickCallback: ->
    this.log "Logged a custom content link click"
