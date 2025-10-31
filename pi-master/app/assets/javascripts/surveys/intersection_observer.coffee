# IntersectionObserver to record when a survey is actually seen(enters the browser viewport).

window.PulseInsightsInclude window.PulseInsights,
  setUpIntersectionObserver: ->
    options =
      root: null
      threshold: this.intersectionThreshold()

    observer = new IntersectionObserver this.handleIntersection, options
    observer.observe this.survey.widget

  handleIntersection: (entries, observer) ->
    PI = window.PulseInsightsObject

    entries.forEach (entry) ->
      # this is needed for a survey demo on the edit page to work https://gitlab.ekohe.com/ekohe/pi/-/issues/1636
      return if PI.submission == undefined

      # skipping an entry that gets generated when the first time the observer is asked to watch the target
      # https://developer.mozilla.org/en-US/docs/Web/API/Intersection_Observer_API#intersection_observer_concepts_and_usage
      return if entry.intersectionRatio < PI.intersectionThreshold()

      PI.jsonpGet "/submissions/#{PI.submission.udid}/viewed_at", { viewed_at: (new Date).toUTCString() }, PI.triggerOnViewCallback

  intersectionThreshold: ->
    0.5 # a callback is triggered as soon as the half of pixels are visible

  intersectionObserverShouldBeSetUp: ->
    !this.userIsIE()
