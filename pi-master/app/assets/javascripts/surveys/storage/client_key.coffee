# Client key
#
# - Store the client key in Local Storage
#

window.PulseInsightsInclude window.PulseInsights,
  clientKeyName: ->
    'pulse_insights_client_key'

  getClientKey: ->
    this.getItemFromStorage(this.clientKeyName())

  updateClientKey: (newClientKey) ->
    this.setItemInStorage(this.clientKeyName(), newClientKey)
