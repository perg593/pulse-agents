# Library to make jsonp calls
#
# https://gist.github.com/icodeforlove/1431613

window.PulseInsightsInclude window.PulseInsights,
  testMode: ->
    document.location.protocol=='file:'

  protocol: ->
    if this.testMode()
      'http:'
    else
      document.location.protocol

  rackAppDomain: ->
    if @customRackAppDomain?
      return @customRackAppDomain
    if this.testMode()
      "localhost:3000"
    else
      "survey.pulseinsights.com"

  host: (domain) ->
    this.log "Set custom Rack app host to '#{domain}'"
    @customRackAppDomain = domain

  jsonpGet: (uri, data, callback) ->
    if not @jsonpRequests?
      @jsonpRequests = 0
    if not @jsonpCallbacks?
      @jsonpCallbacks = {}

    # check if data was passed
    if not arguments[2]?
      callback = arguments[1]
      data = {}

    this.log "JSONP Get with URI #{uri}"

    # TODO - Find a way to dynamically set this up
    src = this.protocol() + "//" + this.rackAppDomain() + uri

    # determine if there already are params
    src += if src.indexOf('?')+1 then '&' else '?'

    head = document.getElementsByTagName('head')[0]
    requestId = @jsonpRequests
    script = document.createElement('script')
    script.async = true if @backgroundCallsEnabled
    script.setAttribute('data-request-id', requestId)

    @jsonpRequests++

    # create external callback name
    data.callback = 'window.PulseInsightsObject.jsonpCallbacks.request_' + requestId

    # set callback function
    @jsonpCallbacks['request_' + requestId] = (data) ->
      # clean up
      head.removeChild script
      # fire callback
      callback.apply window.PulseInsightsObject, [data]

      window.PulseInsightsObject.jsonpCallbacks['request_' + requestId] = (data) ->
        duplicateScript = document.querySelector('script[data-request-id="' + requestId + '"]')
        head.removeChild duplicateScript if duplicateScript?

      # delete callback
      delete window.PulseInsightsObject.jsonpCallbacks['request_' + requestId]

    # traverse data
    params = []

    for key, value of data
      do (key) ->
        params.push key + '=' + encodeURIComponent(value+"")

    # generate params
    src += params.join '&'

    this.log "Complete URL with params"
    this.log src

    # set script attributes
    script.type = 'text/javascript'
    script.src = src

    # add to the DOM
    head.appendChild script
