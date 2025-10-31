# Custom data
#
# Used as:
#  pi('set_custom_data', object);
#   or
#  pi('set_context_data', object);
#
window.PulseInsightsInclude window.PulseInsights,
  set_custom_data: (object) ->
    if typeof(object)!='object'
      object = {data: object}
    if this.checkCustomDataSizeLimit(object)
      this.log "Received custom data object."
      @customData = object
    else
      throw "Custom data too large - 1000 characters maximum."

  set_context_data: (object) ->
    this.set_custom_data(object)

  checkCustomDataSizeLimit: (data) ->
    params = []

    for key, value of data
      do (key) ->
        params.push key + '=' + encodeURIComponent(value)

    src = params.join '&'

    src.length < 1000
