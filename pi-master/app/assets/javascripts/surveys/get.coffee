# Get surveys
#
#
window.PulseInsightsInclude window.PulseInsights,
  get: (what) ->
    if (what == 'surveys')
      this.getSurveys()
    else
      this.log "Not sure what to get: '#{what}'"

  getSurveys: () ->
    library = window.PulseInsightsLibrary

    surveyName = library.getParam('pi_present')?.match(/[-a-zA-Z0-9]+/)[0]
    surveyId = Number(library.getParam('pi_present'))
    questionId = Number(library.getParam('pi_poll'))

    if surveyId > 0 && questionId > 0
      this.present_poll surveyId, questionId
    else if surveyId > 0
      this.present surveyId
    else if surveyName
      this.present surveyName
    else
      this.jsonpGet '/serve', this.collectEnvironmentAttributes(), this.surveysLoaded

  surveysLoaded: (data) ->
    return unless data

    if Object.keys(data).length == 0 && @survey?
      @survey.destroy()
      @survey = null

    if data.device?
      @udid = data.device.udid
      this.updateUDID(@udid)
    if data.survey?
      @submission = data.submission
      this.renderSurvey(data.survey)
    if data.device_data?
      @device_data = data.device_data

  renderSurvey: (survey) ->
    clearInterval(@interval)

    if @survey?
      @survey.destroy()
      @survey = null

    if survey.survey_type == 0
      @survey = new DockedWidgetSurvey(survey)

    else if survey.survey_type == 1
      @survey = new InlineSurvey(survey)

    else if survey.survey_type == 2
      @survey = new TopBarSurvey(survey)

    else if survey.survey_type == 3
      @survey = new BottomBarSurvey(survey)

    else if survey.survey_type == 4
      @survey = new FullscreenSurvey(survey)

    else
      this.log "Error: does not know how to render survey of type #{survey.survey_type}."

    this.createSurveyWidget()
    this.setUpIntersectionObserver() if this.intersectionObserverShouldBeSetUp() # watch the survey widget entering the browser viewport

    window.PulseInsightsObject.triggerOnImpressionCallback()

    if @survey?
      beginDate = Date.now()

      behaviors_to_satisfy = { }

      if @survey.attributes['render_after_intent_exit_enabled'] == 't'
        behaviors_to_satisfy['intent_exit'] = 't'
        behaviors_to_satisfy['intent_exit_satisfied'] = 'f'

      if @survey.attributes['render_after_x_seconds_enabled'] == 't' && @survey.attributes['render_after_x_seconds'] != ''
        behaviors_to_satisfy['x_seconds'] = @survey.attributes['render_after_x_seconds']
        behaviors_to_satisfy['x_seconds_satisfied'] = 'f'

      if @survey.attributes['render_after_x_percent_scroll_enabled'] == 't' && @survey.attributes['render_after_x_percent_scroll'] != ''
        behaviors_to_satisfy['x_percent_scroll'] = @survey.attributes['render_after_x_percent_scroll']
        behaviors_to_satisfy['x_percent_scroll_satisfied'] = 'f'

      if @survey.attributes['render_after_element_visible_enabled'] == 't' && @survey.attributes['render_after_element_visible'] != ''
        behaviors_to_satisfy['e_visible'] = @survey.attributes['render_after_element_visible']
        behaviors_to_satisfy['e_visible_satisfied'] = 'f'

      if @survey.attributes['render_after_element_clicked_enabled'] == 't' && @survey.attributes['render_after_element_clicked'] != ''
        behaviors_to_satisfy['e_clicked'] = @survey.attributes['render_after_element_clicked']
        behaviors_to_satisfy['e_clicked_satisfied'] = 'f'

      if @survey.attributes['text_on_page_enabled'] == 't' && @survey.attributes['text_on_page_selector'] != '' && @survey.attributes['text_on_page_selector'] != ''
        behaviors_to_satisfy['text_on_page_selector'] = @survey.attributes['text_on_page_selector']
        behaviors_to_satisfy['text_on_page_value'] = @survey.attributes['text_on_page_value']
        behaviors_to_satisfy['text_on_page_presence'] = @survey.attributes['text_on_page_presence']
        behaviors_to_satisfy['text_on_page_satisfied'] = 'f'

      if behaviors_to_satisfy['intent_exit']
        @ouibouncer = ouibounce(false,
          aggressive: true
          timer: 500
          sensitivity: 10
          delay: 500
          callback: ->
            behaviors_to_satisfy['intent_exit_satisfied'] = 't'
            if allBehaviorsSatified(behaviors_to_satisfy)
              clearInterval(interval)
              window.PulseInsightsObject.survey.render()
            else
              behaviors_to_satisfy['intent_exit_satisfied'] = 'f'
            return
        )

      interval = setInterval((->
        if behaviors_to_satisfy['text_on_page_presence'] == 't' && document.querySelector(behaviors_to_satisfy['text_on_page_selector']) && document.querySelector(behaviors_to_satisfy['text_on_page_selector']).textContent.includes(behaviors_to_satisfy['text_on_page_value'])
          behaviors_to_satisfy['text_on_page_satisfied'] = 't'

        if behaviors_to_satisfy['text_on_page_presence'] == 'f' && document.querySelector(behaviors_to_satisfy['text_on_page_selector']) && !document.querySelector(behaviors_to_satisfy['text_on_page_selector']).textContent.includes(behaviors_to_satisfy['text_on_page_value'])
          behaviors_to_satisfy['text_on_page_satisfied'] = 't'

        if behaviors_to_satisfy['x_seconds'] && (Date.now() / 1000) - (beginDate / 1000) >= behaviors_to_satisfy['x_seconds']
          behaviors_to_satisfy['x_seconds_satisfied'] = 't'

        if behaviors_to_satisfy['x_percent_scroll'] && (getScrollPercent() >= behaviors_to_satisfy['x_percent_scroll'])
          behaviors_to_satisfy['x_percent_scroll_satisfied'] = 't'

        if behaviors_to_satisfy['e_visible'] && document.querySelector(behaviors_to_satisfy['e_visible']) && elementInViewport(document.querySelector(behaviors_to_satisfy['e_visible']))
          behaviors_to_satisfy['e_visible_satisfied'] = 't'

        if behaviors_to_satisfy['e_clicked']
          elToClick = document.querySelector(behaviors_to_satisfy['e_clicked'])
          if (typeof(elToClick) != 'undefined' && elToClick != null)
            elToClick.onclick = ->
              behaviors_to_satisfy['e_clicked_satisfied'] = 't'

        if allBehaviorsSatified(behaviors_to_satisfy)
          clearInterval(interval)
          window.PulseInsightsObject.survey.render()
      ), 100)

    @interval = interval

  collectEnvironmentAttributes: (pseudo_event) ->
    params =
      udid: this.getUDID()
      device_type: this.deviceType()
      identifier: @identifier || null
      visit_count: this.getVisitCount()
      pageview_count: this.getPageviewCount()
      url: window.location.href
    if this.getClientKey()?
      params['client_key'] = this.getClientKey()
    if @customData?
      params['custom_data'] = this.stringify(@customData)
    if @previewMode
      params['preview_mode'] = true
    params

  createSurveyWidget: ->
    @survey.widgetContainer = document.createElement('div')
    @survey.widgetContainer.setAttribute 'id', '_pi_surveyWidgetContainer'
    @survey.widget = document.createElement('div')
    @survey.widget.setAttribute 'id', '_pi_surveyWidget'
    @survey.widget.setAttribute 'role', 'application'
    @survey.widget.setAttribute 'aria-label', 'Survey'
    @survey.widgetContainer.appendChild @survey.widget

# Inspired by http://www.sitepoint.com/javascript-json-serialization/
  stringify: (obj) ->
    t = typeof obj
    if (t != "object" || obj == null)
      if (t == "string")
        obj = '"'+obj+'"'
      return String(obj)

    else
      json = []
      arr = (obj && obj.constructor == Array)
      self = this

      for n, v of obj
        do (n) ->
          t = typeof(v)

          if (t == "string")
            v = '"'+v+'"'
          else
            if (t == "object" && v != null)
              v = self.stringify(v)

          if arr
            json.push(String(v))
          else
            json.push('"' + n + '":' + String(v))

      if arr
        "[" + String(json) + "]"
      else
        "{" + String(json) + "}"

  allBehaviorsSatified = (behaviors_to_satisfy) ->
    if behaviors_to_satisfy['x_percent_scroll_satisfied'] == 'f' || behaviors_to_satisfy['x_seconds_satisfied'] == 'f' ||
    behaviors_to_satisfy['e_visible_satisfied'] == 'f' || behaviors_to_satisfy['e_clicked_satisfied'] == 'f' ||
    behaviors_to_satisfy['intent_exit_satisfied'] == 'f' || behaviors_to_satisfy['text_on_page_satisfied'] == 'f'
      false
    else
      true

  elementInViewport = (el) ->
    top = el.offsetTop
    left = el.offsetLeft
    width = el.offsetWidth
    height = el.offsetHeight
    while el.offsetParent
      el = el.offsetParent
      top += el.offsetTop
      left += el.offsetLeft
    top >= window.pageYOffset and left >= window.pageXOffset and top + height <= window.pageYOffset + window.innerHeight and left + width <= window.pageXOffset + window.innerWidth

  getScrollPercent = ->
    h = document.documentElement
    b = document.body
    st = 'scrollTop'
    sh = 'scrollHeight'
    (h[st] or b[st]) / ((h[sh] or b[sh]) - (h.clientHeight)) * 100
