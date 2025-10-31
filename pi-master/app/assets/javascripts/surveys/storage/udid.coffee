# UDID
#
# - Store the UDID in Local Storage
#

window.PulseInsightsInclude window.PulseInsights,
  UDIDKeyName: ->
    'pulse_insights_udid'

  getUDID: ->
    key = this.UDIDKeyName()

    if existingUDID = this.getItemFromStorage(key)
      existingUDID
    else
      newUDID = this.createUDID()
      this.setItemInStorage(key, newUDID)
      newUDID

  updateUDID: (newUDID) ->
    this.setItemInStorage(this.UDIDKeyName(), newUDID)

  # should remain in sync with server-side UDID generation algorithm
  createUDID: ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
      r = Math.random()*16|0
      v = if c == 'x' then r else (r&0x3|0x8)
      v.toString(16)
