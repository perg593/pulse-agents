# Visit Track
#
# - Store visit track flag in Local Storage
#

window.PulseInsightsInclude window.PulseInsights,
  visitTrackKeyName: ->
    'pi_visit_track'

  getVisitTrack: ->
    this.getItemFromStorage(this.visitTrackKeyName())

  updateVisitTrack: (visitTrack) ->
    this.setItemInStorage(this.visitTrackKeyName(), visitTrack)

  isNewVisit: (lastVisitEpoch, currentTimeEpoch) ->
    (isNaN(parseInt(lastVisitEpoch)) && lastVisitEpoch != 'true') || parseInt(lastVisitEpoch) + this.expiryEpochTime() < currentTimeEpoch

  expiryEpochTime: ->
    20 * 60 * 1000 # 20 minutes
