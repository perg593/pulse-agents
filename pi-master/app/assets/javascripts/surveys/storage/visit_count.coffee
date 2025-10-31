# Visit Count
#
# - Store the visit count in Local Storage
#

window.PulseInsightsInclude window.PulseInsights,
  visitCountKeyName: ->
    'pi_visit_count'

  getVisitCount: ->
    this.getItemFromStorage(this.visitCountKeyName())

  updateVisitCount: (visitCount) ->
    this.setItemInStorage(this.visitCountKeyName(), visitCount)
