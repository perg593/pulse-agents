# Manage the pi function
#
# - install hook on the array so that it gets instantly executed
# - executing pending commands that got called before the library was loaded
#

window.PulseInsightsInclude window.PulseInsights,
  installHookOnCommandsArray: ->
    this.log 'Installing hook on commands array'
    # Legacy pi syntax
    if (window['pi'] && window['pi'].commands)
      window['pi'].commands.push = ->
        window.PulseInsightsObject.processCommand(args) for args in arguments
    # Alternative 'pulseinsights' syntax because pi sometimes clash with existing stuff
    if (window['pulseinsights'] && window['pulseinsights'].commands)
      window['pulseinsights'].commands.push = ->
        window.PulseInsightsObject.processCommand(args) for args in arguments

  processPendingCommands: ->
    if (window['pi'] && window['pi'].commands)
      this.log "Processing #{window['pi'].commands.length} commands that are pending"
      this.processCommand(command) while (command = window['pi'].commands.shift())
    if (window['pulseinsights'] && window['pulseinsights'].commands)
      this.log "Processing #{window['pulseinsights'].commands.length} commands that are pending"
      this.processCommand(command) while (command = window['pulseinsights'].commands.shift())

  processCommand: (args) ->
    # convert arguments to an array
    argumentsArray = [].slice.call(args)

    # get the function as first argument
    theFunction = this.getFunction(argumentsArray[0])

    if theFunction == undefined
      @log "Unknown command: #{argumentsArray[0]}"
      return

    # pass the other arguments
    try
      theFunction.apply this, argumentsArray[1..-1]
    catch error
      @log "Error while executing command: "+error

  getFunction: (functionName) ->
    {
      'debug': this.debug,
      'get': this.get,
      'host': this.host,
      'identify': this.identify,
      'identify_client': this.identify_client,
      'onanswer': this.onanswer,
      'oncomplete': this.oncomplete,
      'onclose': this.onclose,
      'onimpression': this.onimpression,
      'onview': this.onview,
      'onclick': this.onclick,
      'present': this.present,
      'present_poll': this.present_poll,
      'present_results': this.present_results,
      'preview': this.preview,
      'set_custom_data': this.set_custom_data,
      'set_context_data': this.set_context_data,
      'set_device_data': this.set_device_data,
      'spa': this.spa,
      'background_calls': this.backgroundCalls,
      'designate_pdf_results': this.designatePdfResults,
      'visitor_tracking': this.visitor_tracking,
      'pushBeforeGet': this.pushBeforeGet,
      'track_event': this.trackEvent
    }[functionName]
