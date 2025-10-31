# Device data
#
# Used as:
#  pi('set_device_data', object);
#
window.PulseInsightsInclude window.PulseInsights,
  set_device_data: (object) ->
    if typeof(object)!='object'
      object = {data: object}

    if @device_data
      for attrname of object
        @device_data[attrname] = object[attrname]
    else
      @device_data = {}
      for attrname of object
        @device_data[attrname] = object[attrname] unless attrname in ['identifier', 'callback']

    object['identifier'] = this.identifier

    if this.checkCustomDataSizeLimit(object)
      this.jsonpGet "/devices/#{this.getUDID()}/set_data", object, this.deviceDataSent
      this.log "Received custom data object."
    else
      throw "Custom data too large - 1000 characters maximum."

  deviceDataSent: (data) ->
    this.log "Device data sent"

  checkCustomDataSizeLimit: (data) ->
    params = []

    for key, value of data
      do (key) ->
        params.push key + '=' + encodeURIComponent(value)

    src = params.join '&'

    src.length < 1000
