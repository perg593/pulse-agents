# Track Event - Used to log important events that happened on the user's site like purchase
#
# Used as:
#  pi('track_event', <event_name>, <event_properties>);
#
window.PulseInsightsInclude window.PulseInsights,
  trackEvent: (name, properties) ->
    this.jsonpGet "/track_event", this.eventParameters(name, properties), this.eventSent

  eventSent: ->
    this.log "Event has been sent"

  eventParameters: (name, properties) ->
    event_name: name
    event_properties: JSON.stringify properties
    identifier: @identifier || null
    udid: this.getUDID()
    url: window.location.href
