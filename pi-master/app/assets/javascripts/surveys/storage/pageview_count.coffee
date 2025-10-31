# Pageview Count
#
# - Store pageview count in Local Storage
#

window.PulseInsightsInclude window.PulseInsights,
  pageviewCountKeyName: ->
    'pi_pageview_count'

  getPageviewCount: ->
    this.getItemFromStorage(this.pageviewCountKeyName())

  updatePageviewCount: (pageviewCount) ->
    this.setItemInStorage(this.pageviewCountKeyName(), pageviewCount)
