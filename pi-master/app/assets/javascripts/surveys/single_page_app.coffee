# Handler for SPAs.
# Calls "pi('get', 'surveys')" on 'pushState' and 'hashchange'.

window.PulseInsightsInclude.initializeSinglePageApp = () ->
  ((history) ->
    pushState = history.pushState
    history.pushState = (state) ->
      if typeof history.onpushstate == 'function'
        history.onpushstate state: state

      if window.PulseInsightsObject.pushBeforeGetEnabled
        pushState.apply history, arguments
        if window.PulseInsightsObject.isSpaEnabled()
          pi 'get', 'surveys'
          window.PulseInsightsObject.log("pushState with new URL #{window.location.href}")
          window.PulseInsightsObject.incrementPageviews()
      else
        if window.PulseInsightsObject.isSpaEnabled()
          pi 'get', 'surveys'
          window.PulseInsightsObject.log("pushState with new URL #{window.location.href}")
          window.PulseInsightsObject.incrementPageviews()
        pushState.apply history, arguments

    return
  ) window.history

  if 'onhashchange' of window
    if window.onhashchange
      existing_onhashchange = window.onhashchange

    window.onhashchange = ->
      if window.PulseInsightsObject.isSpaEnabled()
        pi 'get', 'surveys'
        window.PulseInsightsObject.log("onhashchange with new URL #{window.location.href}")
        window.PulseInsightsObject.incrementPageviews()
      if existing_onhashchange
        existing_onhashchange()
      return
