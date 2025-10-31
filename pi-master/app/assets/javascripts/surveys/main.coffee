# Main - where everything starts
#
class window.PulseInsights
  constructor: ->
    if this.userIsBot()
      this.log "Bot was blocked: #{navigator.userAgent}"
    else if this.userIsOldIE()
      this.log "Old IE was blocked: #{navigator.userAgent}"
    else if !this.supportsLocalStorage()
      this.log "localStorage not supported: #{navigator.userAgent}"
    else
      @pushBeforeGetEnabled = false
      @debugMode = false
      @spaEnabled = true
      @previewMode = this.isPreviewMode()
      if @previewMode
        this.log "Live preview mode enabled, answers won't be posted and triggering rules ignored."
      this.incrementPageviews()
      this.incrementVisits()
      this.installHookOnCommandsArray()
      this.processPendingCommands()

  log: (message) ->
    unless @logMessages?
      @logMessages = []
    @logMessages.push message
    if @debugMode == true
      console.log("Pulse Insights: " + message)

  printLog: ->
    console.log("Pulse Insights: " + message) for message in @logMessages
    true

  debug: (enable) ->
    @debugMode = enable
    if @debugMode == true
      this.log 'Debug mode enabled.'

  # pi('spa', false); to disable SPA behaviors
  spa: (enable) ->
    @spaEnabled = enable
    if this.isSpaEnabled()
      this.log 'SPA mode enabled.'
    else
      this.log 'SPA mode disabled.'

  isSpaEnabled: ->
    @spaEnabled

  backgroundCalls: (enable) ->
    @backgroundCallsEnabled = enable
    this.log "Background calls #{if @backgroundCallsEnabled then 'enabled' else 'disabled'}."

  designatePdfResults: (enable) ->
    @pdfResultsDesignated = enable
    this.log "PDF results #{if @pdfResultsDesignated then 'enabled' else 'disabled'}."

  pushBeforeGet: (enable) ->
    @pushBeforeGetEnabled = enable
    if @pushBeforeGetEnabled == true
      this.log 'Push Before Get mode enabled.'
    else
      this.log 'Push Before Get mode disabled.'

  pushBeforeGetEnabled: ->
    @pushBeforeGetEnabled

  isPreviewMode: ->
    searchParams = new URLSearchParams(window.location.search)
    livePreviewIsEnabled = searchParams.get('pi_live_preview')

    if livePreviewIsEnabled == "false" || livePreviewIsEnabled == "0" || livePreviewIsEnabled == "f" || livePreviewIsEnabled=='disabled'
      this.eraseCookie('pi_live_preview')
      return false

    if livePreviewIsEnabled == "true" || livePreviewIsEnabled == "1" || livePreviewIsEnabled == "t" || livePreviewIsEnabled=='enabled'
      this.createCookie('pi_live_preview', 'true', 20)
      return true

    if this.readCookie('pi_live_preview')=="true"
      return true

    false

  preview: (enable) ->
    @previewMode = enable
    if @previewMode == true
      this.log "Preview mode enabled, answers won't be posted"

  poll_results_for_preview: (poll_results) ->
    if @previewMode == true
      @poll_results_for_preview = (poll_results)

  identify: (identifier) ->
    this.log "Identifier is now set to '#{identifier}'."
    @identifier = identifier

  identify_client: (client_key) ->
    this.log "Client key is now set to '#{client_key}'."
    this.updateClientKey(client_key)
    this.client_key = client_key

  incrementPageviews: ->
    if pageviewCount = this.getPageviewCount()
      this.updatePageviewCount(parseInt(pageviewCount, 10) + 1)
    else
      this.updatePageviewCount(1)

  incrementVisits: ->
    lastVisitEpoch = this.getVisitTrack()
    currentTimeEpoch = Date.now()

    if lastVisitEpoch == 'true'
      this.updateVisitTrack(currentTimeEpoch) # set epoch time

    if this.isNewVisit(lastVisitEpoch, currentTimeEpoch)
      this.updatePageviewCount(1)             # reset page view
      if visitCount = this.getVisitCount()
        this.updateVisitCount(parseInt(visitCount, 10) + 1)
      else
        this.updateVisitCount(1)

    this.updateVisitTrack(currentTimeEpoch) # set epoch time

  userIsBot: ->
    /bot|google|baidu|bing|msn|duckduckbot|teoma|slurp|yandex/i.test(navigator.userAgent)

  userIsOldIE: ->
    document.documentMode < 9

  userIsIE: ->
    document.documentMode
