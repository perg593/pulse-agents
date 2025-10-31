# Toggle visitor tracking.
# Sets whether or not the user has consented to tracking (i.e. cookies/localStorage)
#
# Used as:
#  pi('visitor_tracking', boolean);
#
window.PulseInsightsInclude window.PulseInsights,
  visitorTrackingKeyName: ->
    'pi_visitor_tracking'

  visitor_tracking: (enabled) ->
    this.log "Setting visitor tracking to " + enabled
    was_disabled = this.getItemFromStorage(this.visitorTrackingKeyName()) == "false"

    this.setItemInStorage(this.visitorTrackingKeyName(), enabled, force=true)

    if enabled
      if was_disabled
        this.updateUDID(this.createUDID())
        this.updatePageviewCount(1)
        this.updateVisitCount(1)
    else
      # user revoked tracking permission
      # destroy all stored cookies and data
      localStorage.removeItem(this.pageviewCountKeyName())
      localStorage.removeItem(this.visitTrackKeyName())
      localStorage.removeItem(this.visitCountKeyName())
      localStorage.removeItem(this.UDIDKeyName())
      localStorage.removeItem(this.clientKeyName())

      this.eraseCookie('pi_pageview_count')
      this.eraseCookie('pi_visit_track')
      this.eraseCookie('pi_visit_count')
      this.eraseCookie('pi_live_preview')
      this.eraseCookie('pulse_insights_client_key')
      this.eraseCookie('pulse_insights_udid')
