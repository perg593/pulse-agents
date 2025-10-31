# Show results
#
#
window.PulseInsightsInclude window.PulseInsights,
  present_results: (submissionUdid) ->
    this.jsonpGet "/present_results", { submission_udid: submissionUdid, identifier: @identifier }, this.showResults

  showResults: (data) ->
    if data.poll
      survey = new TopBarSurvey({id: 'poll-results', question: [data.question]})
      survey.renderCSS()

      if window.PulseInsightsObject.isMobile() && (@attributes["survey_type"]!=1 && @attributes["survey_type"]!=3)
        survey.insertCSS(this.mobileCssStyle())

      @widgetContainer = document.createElement('div')
      @widgetContainer.setAttribute 'id', '_pi_surveyWidgetContainer'
      @widget = document.createElement('div')
      @widget.setAttribute 'id', '_pi_surveyWidget'

      @widgetContent = document.createElement('div')
      @widgetContent.setAttribute 'class', '_pi_widgetContentContainer'
      @widget.appendChild @widgetContent

      @widgetContent.innerHTML = ""

      @widgetContainer.appendChild @widget

      questionElement = document.createElement 'div'
      questionElement.setAttribute 'class', "_pi_question"
      questionElement.innerHTML = data.content
      @widgetContent.appendChild questionElement

      totalCount = 0
      for result in data.poll
        totalCount += parseInt(result.count)

      # container
      pollContainer = document.createElement 'div'
      pollContainer.setAttribute 'class', '_pi_pollContainer'

      for result, index in data.poll
        resultCount = parseInt(result.count)

        resultPercentage = Math.round((resultCount * 100) / totalCount)

        # choice
        pollChoice = document.createElement 'label'
        pollChoice.setAttribute 'class', '_pi_pollChoice'

        # chart
        pollChart = document.createElement 'span'
        pollChart.setAttribute 'class', '_pi_pollChart'
        pollChart.setAttribute 'data-percent', resultPercentage
        pollChoice.appendChild(pollChart)

        # text
        pollText = document.createElement 'span'
        pollText.setAttribute 'class', '_pi_pollText'

        # progression
        pollFiller = document.createElement 'span'
        pollFiller.style.opacity = '0'
        if resultPercentage >= 10
          pollFiller.innerHTML = '0'
        else
          pollFiller.innerHTML = '00'
        pollText.appendChild(pollFiller)

        pollProgress = document.createElement 'div'
        pollProgress.setAttribute 'class', '_pi_pollProgress'
        pollProgress.innerHTML = "#{resultPercentage}% (#{result.count.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")} responses)"

        # name
        pollName = document.createElement 'div'
        pollName.setAttribute 'class', '_pi_pollName'
        pollName.innerHTML = survey.formatText(result.content)

        pollChoice.appendChild(pollText)
        pollContainer.appendChild(pollName)
        pollContainer.appendChild(pollChoice)
        pollContainer.appendChild(pollProgress)
        pollContainer.style.transition = 'all .3s cubic-bezier(0.5,1.2,.5,1.2)'

        @widgetContent.appendChild pollContainer

      survey.widgetParent().insertBefore @widgetContainer, survey.widgetParent().childNodes[0]

      # add width style to trigger css animation
      container = @widget
      setTimeout ->
        container.setAttribute 'style', "max-height: 1999px"

        for pollChart in document.getElementsByClassName("_pi_pollChart")
          percent = pollChart.getAttribute 'data-percent'
          pollChart.style.width = "#{percent}%"
      , 100
    else if data.thank_you
      survey = new TopBarSurvey({id: 'thank-you', question: []})
      survey.renderCSS()

      if window.PulseInsightsObject.isMobile() && (@attributes["survey_type"]!=1 && @attributes["survey_type"]!=3)
        survey.insertCSS(this.mobileCssStyle())

      @widgetContainer = document.createElement('div')
      @widgetContainer.setAttribute 'id', '_pi_surveyWidgetContainer'

      @widget = document.createElement('div')
      @widget.setAttribute 'id', '_pi_surveyWidget'

      # Get class name for IE
      @widget.setAttribute 'survey-widget-type', this.constructor.name.toLowerCase()

      if window.PulseInsightsObject.isMobile()
        @widgetContainer.setAttribute 'class', 'mobile-enabled'

      @widgetContent = document.createElement('div')
      @widgetContent.setAttribute 'class', '_pi_widgetContentContainer'

      @widget.appendChild @widgetContent

      @widgetContainer.appendChild @widget
      survey.widgetParent().insertBefore @widgetContainer, survey.widgetParent().childNodes[0]

      thankYouSurvey = document.createElement 'div'
      thankYouSurvey.setAttribute 'class', '_pi_thankYouSurvey'
      thankYouSurvey.innerHTML = survey.formatText(data.thank_you)

      @widgetContent.innerHTML = ""
      @widgetContent.appendChild thankYouSurvey

      # Animation
      container = @widget
      height = survey.height()
      setTimeout ->
        container.setAttribute 'style', "max-height: 1999px"
      , 10

