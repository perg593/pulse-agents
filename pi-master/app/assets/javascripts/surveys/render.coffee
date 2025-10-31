window.PulseInsightsInclude window.Survey,
  render: ->
    this.renderCSS()
    # Do not include the mobile CSS for inline survey types
    if window.PulseInsightsObject.isMobile() && (@attributes["survey_type"]!=1 && @attributes["survey_type"]!=3)
      this.insertCSS(this.mobileCssStyle())

    this.renderThemeCss()
    this.renderCustomCSS()

    @widgetContainer.onclick = window.PulseInsightsObject.survey.widgetContainerClickedEvent

    @widget.setAttribute 'data-survey-locale-group-id', @attributes['survey_locale_group_id']

    if @attributes['display_all_questions'] == 't'
      @widget.setAttribute 'data-survey-display', 'all-at-once'

    @widget.setAttribute 'survey-widget-type', this.widgetType()

    widgetContainerClass = ""
    if window.PulseInsightsObject.isMobile()
      widgetContainerClass = "mobile-enabled"

    hasTouch = 'ontouchstart' in window
    if hasTouch
      widgetContainerClass = widgetContainerClass + " has-touch"

    @widgetContainer.setAttribute 'class', widgetContainerClass

    widgetContainerClass = ""
    if window.PulseInsightsObject.isMobile()
      widgetContainerClass = "mobile-enabled"

    hasTouch = 'ontouchstart' in window
    if hasTouch
      widgetContainerClass = widgetContainerClass + " has-touch"
    if @attributes['display_all_questions'] == 't'
      widgetContainerClass = widgetContainerClass + " all-at-once"

    @widgetContainer.setAttribute 'class', widgetContainerClass

    @accessibilitySpan = document.createElement('span')
    @accessibilitySpan.setAttribute 'class', '_pi_accessibilityHidden'
    @accessibilitySpan.innerHTML = 'Survey'
    @accessibilitySpan.setAttribute 'style', 'display: none;'

    @widget.appendChild @accessibilitySpan

    @closeButton = document.createElement('div')
    @closeButton.setAttribute 'class', '_pi_closeButton'
    @closeButton.setAttribute 'aria-label', 'Close Survey'
    @closeButton.setAttribute 'tabindex', '0'
    @closeButton.setAttribute 'role', 'button'
    @closeButton.appendChild document.createTextNode('×')
    @closeButton.addEventListener 'keydown', (event) ->
      if event.key == 'Enter'
        event.preventDefault()
        window.PulseInsightsObject.survey.closeButtonClickedEvent()

    @closeButton.onclick = window.PulseInsightsObject.survey.closeButtonClickedEvent
    @widget.appendChild @closeButton

    @widgetContent = document.createElement('div')
    @widgetContent.setAttribute 'class', '_pi_widgetContentContainer'

    if @attributes["background"]? && @attributes["background"] != ''
      backgroundContainer = document.createElement('img')
      backgroundContainer.setAttribute 'src', @attributes['background']
      backgroundContainer.setAttribute 'class', '_pi_background_image'
      @widget.appendChild backgroundContainer

    if this.invitationText()
      invitation = document.createElement('div')
      invitation.setAttribute 'class', '_pi_invitationTextContainer'
      invitation.innerHTML = this.formatText this.invitationText()
      invitation.onclick = window.PulseInsightsObject.survey.startButtonClickedEvent
      @widgetContent.appendChild invitation

      startButton = document.createElement('a')
      startButton.setAttribute 'class', '_pi_startButton'
      startButton.setAttribute 'href', 'javascript:void(0)'

      unless this.invitationButtonDisabled() == 't'
        startText = this.invitationButtonText() || "Start"
        startButton.innerHTML = this.escapeText(startText)
        startButton.onclick = window.PulseInsightsObject.survey.startButtonClickedEvent
        @widgetContent.appendChild startButton

    @widget.appendChild @widgetContent

    if @attributes['pulse_insights_branding']
      branding = document.createElement('a')
      branding.setAttribute 'class', '_pi_branding'
      branding.setAttribute 'href', "http://pulseinsights.com?utm_source=survey_widget&utm_medium=client_site_referral&utm_campaign=#{window.PulseInsightsObject.identifier}"
      branding.setAttribute 'target', '_blank'
      branding.appendChild document.createTextNode('Crafted with Pulse Insights')
      @widget.appendChild branding

    renderPosition =
      switch @attributes["inline_target_position"]
        when "0" then 'below'
        when "1" then 'above'
        when "2" then 'before'
        when "3" then 'after'
        else null

    widgetParent = this.widgetParent()

    if typeof widgetParent is "undefined"
      that = this
      i = 0
      t = setInterval (->
        widgetParent = that.widgetParent()
        i++
        if i == 100
          clearInterval(t)
        if typeof widgetParent isnt "undefined"
          clearInterval(t)
          that.insertWidgetContainer(that.widgetContainer, widgetParent, renderPosition)
      ), 100
    else
      this.insertWidgetContainer(@widgetContainer, this.widgetParent(), renderPosition)

    if not this.invitationText()
      if PulseInsightsObject.poll?
        this.renderResults(PulseInsightsObject.poll)
      else
        this.loadQuestions()

    # Animation
    container = @widget
    height = this.height()
    setTimeout ->
      container.setAttribute 'style', "max-height: 1999px"
    , 10

  renderAllQuestions: ->
    @widgetContent.innerHTML = ""
    display_all_questions = true

    for question in @questions
      if question.question_type == 'custom_content_question' && question.show_after_aao
        @custom_content_thank_you = question
        continue
      this.question = question
      this.renderCurrentQuestion(display_all_questions)

    @submitButtonContainer = document.createElement 'div'
    @submitButtonContainer.setAttribute 'class', '_pi_all_questions_submit_button_container'

    @allSubmitButtonError = document.createElement 'div'
    @allSubmitButtonError.setAttribute 'class', '_pi_all_at_once_submit_error'
    @allSubmitButtonError.setAttribute 'role', 'alert' if this.attributes.all_at_once_empty_error_enabled == 'f'

    @allSubmitButton = document.createElement 'input'
    @allSubmitButton.setAttribute 'class', '_pi_all_questions_submit_button'
    @allSubmitButton.setAttribute 'type', 'submit'
    @allSubmitButton.setAttribute 'value', this.attributes.all_at_once_submit_label
    @allSubmitButton.setAttribute 'data-submit-error', true
    @allSubmitButton.onclick = window.PulseInsightsObject.survey.allQuestionsSubmitClicked

    @submitButtonContainer.appendChild @allSubmitButton
    @submitButtonContainer.appendChild @allSubmitButtonError

    @widgetContent.appendChild @submitButtonContainer

  renderCurrentQuestion: (display_all_questions = false) ->
    # Only set focus while loading the next question
    if (!display_all_questions && @question.position != 0)
      this.focusOnLoadingInterstitial()

    @widgetContent.innerHTML = "" unless display_all_questions

    questionElement = document.createElement 'div'
    questionElement.setAttribute 'class', "_pi_question _pi_question_#{@question.question_type}"
    questionElement.setAttribute 'id', "_pi_question_#{@question.id}"
    questionElement.setAttribute 'data-question-id', @question.id
    questionElement.setAttribute 'data-question-locale-group-id', @question.question_locale_group_id
    questionElement.setAttribute 'data-error-text', @question.error_text

    if @question.question_type == 'custom_content_question'
      body = document.getElementsByTagName('body')[0]
      regex = /<script\b[^>]*>([\s\S]*?)<\/script>/gm

      match = undefined
      while match = regex.exec(@question.content)
        script = document.createElement('script')
        script.type = 'text/javascript'
        script.text = match[1]
        body.appendChild(script)

      questionElement.innerHTML = @question.content
    else
      @widget.setAttribute 'id', '_pi_surveyWidget'
      @closeButton.setAttribute 'class', '_pi_closeButton'
      questionElement.innerHTML = this.formatText(@question.content)

    @widgetContent.appendChild questionElement

    if @attributes['custom_content_link_click_enabled'] == 't'
      for link in questionElement.getElementsByTagName('a')
        link.addEventListener 'click', (e) ->
          PI = window.PulseInsightsObject

          PI.triggerOnClickCallback(e)

          e.preventDefault() if PI.debugMode
          # This is necessary for the widget preview to work https://gitlab.ekohe.com/ekohe/pi/-/issues/1636
          return if PI.submission == undefined
          # Question ID is taken this way to support both all-at-once survey and one-at-a-time survey
          questionId = this.closest('._pi_question').dataset.questionId # TODO: re-check if we really dropped IE
          linkIdentifier = this.dataset.piLinkId
          PI.logCustomContentLinkClick(questionId, linkIdentifier)

    possibleAnswersContainer =
      if @question.button_type == 2
        possibleAnswersContainer = document.createElement 'div'
      else
        possibleAnswersContainer = document.createElement 'ul'

    possibleAnswersContainer.setAttribute 'class', '_pi_answers_container'

    ariaLabelledBy = ""
    ariaLabelledBy = "_pi_header_before_#{@question.id} " if this.questionHasBeforeText()
    ariaLabelledBy = "#{ariaLabelledBy}_pi_question_#{@question.id}"
    ariaLabelledBy = "#{ariaLabelledBy} _pi_header_after_#{@question.id}" if this.questionHasAfterText()

    possibleAnswersContainer.setAttribute 'aria-labelledby', ariaLabelledBy

    if @attributes['display_all_questions'] == 'f'
      @widget.setAttribute 'data-question-id', @question.id
      possibleAnswersContainer.setAttribute 'data-question-id', @question.id
      @widget.setAttribute 'data-question-type', @question.question_type
      possibleAnswersContainer.setAttribute 'data-question-type', @question.question_type
    else
      possibleAnswersContainer.setAttribute 'data-question-id', @question.id
      possibleAnswersContainer.setAttribute 'data-question-type', @question.question_type
      if possibleAnswersContainer.getAttribute('data-question-type') == 'custom_content_question'
        possibleAnswersContainer.setAttribute 'data-question-optional', 't'
      else
        possibleAnswersContainer.setAttribute 'data-question-optional', @question.optional

    answers_per_row = if window.PulseInsightsObject.isMobile() then @question.answers_per_row_mobile else @question.answers_per_row_desktop
    radio_button = if @question.button_type == 1 then 'off' else 'on'

    # Adding flex display only for questions created after new alignments feature (2019-04-01) -- Remove it otherwise
    if this.displayFlexDisplay()
      this.insertCSS(this.flexCssStyle(), 'pi_flex_display')
    else
      this.removeCss('pi_flex_display')

    @widget.setAttribute 'data-question-nps', @question.nps
    possibleAnswersContainer.setAttribute 'data-question-nps', @question.nps

    width_type = if window.PulseInsightsObject.isMobile() then @question.mobile_width_type else @question.desktop_width_type
    answers_layout = if width_type == 1 then 'variable' else 'fixed'
    alignment = if window.PulseInsightsObject.isMobile() then @question.answers_alignment_mobile else @question.answers_alignment_desktop

    # Still here for backward compatibility (we had only these 3 option: fixed, variable-left, variable-center)
    answer_widths =
      if width_type == 1 && alignment == 0
        'variable-left'
      else if width_type == 1 && alignment == 1
        'variable-center'
      else if width_type == 0 || @question.question_type == 'multiple_choices_question'
        'fixed'
      else
        ''

    possibleAnswersContainer.setAttribute 'data-answers-layout', answers_layout
    @widget.setAttribute 'data-answers-layout', answers_layout

    answers_alignment =
      switch alignment
        when 0 then 'left'
        when 1 then 'center'
        when 2 then 'right'
        when 3 then 'space-between'
        when 4 then 'space-around'
        when 5 then 'space-evenly'
        else ''

    possibleAnswersContainer.setAttribute 'data-answers-alignment', answers_alignment
    @widget.setAttribute 'data-answers-alignment', answers_alignment

    if answer_widths && @attributes['display_all_questions'] == 'f'
      @widget.setAttribute 'data-answer-widths', answer_widths
      possibleAnswersContainer.setAttribute 'data-answer-widths', answer_widths
    else if answer_widths && @attributes['display_all_questions'] == 't'
      possibleAnswersContainer.setAttribute 'data-answer-widths', answer_widths
    else
      @widget.removeAttribute 'data-answer-widths'

    if answers_per_row && @attributes['display_all_questions'] == 'f'
      @widget.setAttribute 'data-answers-per-row', answers_per_row
      possibleAnswersContainer.setAttribute 'data-answers-per-row', answers_per_row
    else if answers_per_row && @attributes['display_all_questions'] == 't'
      possibleAnswersContainer.setAttribute 'data-answers-per-row', answers_per_row
    else
      @widget.removeAttribute 'data-answers-per-row'

    if radio_button && @attributes['display_all_questions'] == 'f'
      @widget.setAttribute 'data-radio-button', radio_button
      possibleAnswersContainer.setAttribute 'data-radio-button', radio_button
    else if radio_button && @attributes['display_all_questions'] == 't'
      possibleAnswersContainer.setAttribute 'data-radio-button', radio_button
    else
      @widget.removeAttribute 'data-radio-button'

    if @question.possible_answers && @attributes['display_all_questions'] == 'f'
      @widget.setAttribute 'data-possible-answers', @question.possible_answers.length
      possibleAnswersContainer.setAttribute 'data-possible-answers', @question.possible_answers.length
    else if @question.possible_answers && @attributes['display_all_questions'] == 't'
      possibleAnswersContainer.setAttribute 'data-possible-answers', @question.possible_answers.length
    else
      @widget.removeAttribute 'data-possible-answers'

    if @question.question_type=='single_choice_question'
      @renderSingleChoiceQuestion(possibleAnswersContainer, display_all_questions)

    if @question.question_type=='multiple_choices_question'
      @renderMultipleChoicesQuestion(possibleAnswersContainer, display_all_questions)

    if @question.question_type == 'free_text_question'
      @renderFreeTextQuestion(possibleAnswersContainer, display_all_questions)

    if @question.question_type == 'slider_question'
      @renderSliderQuestion(possibleAnswersContainer, display_all_questions)

    if @question.question_type == 'custom_content_question'
      this.addEventListenerToNextQuestionButtons()

      if @question.fullscreen == 't'
        @widget.setAttribute 'id', '_pi_surveyWidgetCustom'
        @closeButton.setAttribute 'class', '_pi_closeCustomButton'
        questionElement.setAttribute 'class', "_pi_question _pi_question_#{@question.question_type} _pi_question_#{@question.question_type}_fullscreen"

        if @question.opacity?
          document.getElementById('_pi_surveyWidgetCustom').style.opacity = '.' + @question.opacity
        else
          document.getElementById('_pi_surveyWidgetCustom').style.opacity = '.9'

        if @question.background_color?
          document.getElementById('_pi_surveyWidgetCustom').style.background = @question.background_color
        else
          document.getElementById('_pi_surveyWidgetCustom').style.background = 'white'

      if @question.autoclose_enabled == 't' && @question.autoclose_delay?
        setTimeout ->
          window.PulseInsightsObject.survey.submitSurveyClosed()
          window.PulseInsightsObject.triggerOnCompleteCallback()
          window.PulseInsightsObject.survey.tearDownWidget()
        , @question.autoclose_delay * 1000
      else if @question.autoredirect_enabled == 't' && @question.autoredirect_url? && @question.autoredirect_delay?
        redirect_url = @question.autoredirect_url
        setTimeout ->
          window.location = redirect_url
        , @question.autoredirect_delay * 1000

    if @question.additional_content && @question.additional_content_position == 2 # Above question.content
      questionElement.parentNode.insertBefore(this.additionalContentElement(), questionElement)

    if @question.additional_content && @question.additional_content_position == 0 # Between
      @widgetContent.appendChild(this.additionalContentElement())

    @widgetContent.appendChild possibleAnswersContainer

    if @question.additional_content && @question.additional_content_position == 1 # Footer
      @widgetContent.appendChild(this.additionalContentElement())

    this.addEventListenerToNextQuestionButtons()

    this.handleAdditionalText(questionElement, possibleAnswersContainer)

    if (!display_all_questions && @question.position != 0)
      this.setFocusAfterLoad()

  addEventListenerToNextQuestionButtons: ->
    nextQuestionButtons = document.getElementsByClassName('pi_question_link')

    for nextQuestionButton in nextQuestionButtons
      nextQuestionButton.onclick = window.PulseInsightsObject.survey.nextQuestionButtonClicked

  loadingInterstitial: ->
    # The accessibility span is accessible throughout the life of the survey
    # So it makes a good placeholder for focus during question transitions
    @accessibilitySpan

  focusOnLoadingInterstitial: ->
    if window.PulseInsightsObject.survey.controlTransitionFocus
      this.loadingInterstitial().setAttribute 'style', 'display: block;'
      this.loadingInterstitial().setAttribute 'tabindex', '0'
      this.loadingInterstitial().focus()

  resetLoadingInterstitial: ->
    this.loadingInterstitial().setAttribute 'style', 'display: none;'
    this.loadingInterstitial().removeAttribute 'tabindex'

  findFocusTarget: ->
    if @renderedThankYou
      focusTarget = document.getElementsByClassName("_pi_thankYouSurvey")[0]
    else if @renderedResults
      focusTarget = document.getElementsByClassName("_pi_question")[0]
    else if @question.question_type == 'single_choice_question'
      if @question.button_type == 2
        focusTarget = document.getElementsByClassName("_pi_select")[0]
      else
        focusTarget = document.querySelectorAll("._pi_answers_container a")[0]
    else if @question.question_type=='multiple_choices_question'
      focusTarget = document.getElementsByClassName("_pi_checkbox")[0]
    else if @question.question_type == 'free_text_question'
      focusTarget = document.getElementsByClassName("_pi_free_text_question_field")[0]
    else if @question.question_type == 'slider_question'
      focusTarget = document.getElementsByClassName("_pi_hidden_slider")[0]
    else if @question.question_type == 'custom_content_question'
      focusTarget = document.getElementsByClassName("_pi_question_custom_content_question")[0]
      focusTarget.setAttribute 'tabindex', '0'
    focusTarget

  setFocusAfterLoad: ->
    if window.PulseInsightsObject.survey.controlTransitionFocus
      window.PulseInsightsObject.survey.setControlTransitionFocus(false)
      if document.activeElement == this.loadingInterstitial()
        focusTarget = this.findFocusTarget()
        if focusTarget != undefined && focusTarget != null
          focusTarget.focus()
          this.resetLoadingInterstitial()

  additionalContentElement: ->
    if @question.additional_content
      additionalContent = document.createElement "div"
      additionalContent.setAttribute "class", "_pi_additional_content"

      positionName = if @question.additional_content_position == 0
        "header"
      else if @question.additional_content_position == 1
        "footer"
      else if @question.additional_content_position == 2
        "super-header"

      additionalContent.setAttribute 'data-position', positionName
      additionalContent.innerHTML = @question.additional_content
      additionalContent

  renderResults: (results) ->
    this.focusOnLoadingInterstitial()

    @widgetContent.innerHTML = ""

    questionElement = document.createElement 'div'
    questionElement.setAttribute 'class', "_pi_question"
    questionElement.setAttribute 'tabindex', "0"

    question = this.question || PulseInsightsObject.question

    questionElement.innerHTML = this.formatText(question.content)
    @widgetContent.appendChild questionElement

    self = this

    totalCount = 0
    for result in results
      totalCount += parseInt(result.count)

    answerIds = this.multipleChoiceAnswerIds(question.id) if question.question_type == 'multiple_choices_question'

    # add current answer to totalCount
    if question.question_type == 'single_choice_question'
      totalCount += 1
    if question.question_type == 'multiple_choices_question'
      totalCount += answerIds.length

    # container
    pollContainer = document.createElement 'div'
    pollContainer.setAttribute 'class', '_pi_pollContainer'

    for result, index in results
      resultCount = parseInt(result.count)

      # add current answer
      resultCount += 1 if question.question_type == 'single_choice_question' && @answerId == result.id # single_choice
      resultCount += 1 if question.question_type == 'multiple_choices_question' && answerIds.includes(result.id) # multiple_choice

      resultPercentage =
        if totalCount > 0
          Math.round((resultCount * 100) / totalCount)
        else
          0

      formattedResultCount = resultCount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")

      # choice
      pollChoice = document.createElement 'label'
      pollChoice.setAttribute 'class', '_pi_pollChoice'
      pollChoice.setAttribute 'tabindex', '0'
      pollChoice.setAttribute 'role', 'figure'
      pollChoice.setAttribute 'aria-label', "#{resultPercentage}% (#{formattedResultCount} responses)"

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
      pollFiller.innerHTML = "#{resultPercentage}%"
      pollText.appendChild(pollFiller)

      pollProgress = document.createElement 'div'
      pollProgress.setAttribute 'class', '_pi_pollProgress'

      pollProgressPercentage = document.createElement 'div'
      pollProgressPercentage.setAttribute 'class', '_pi_pollProgressPercentage'
      pollProgressPercentage.innerHTML = "#{resultPercentage}%"

      pollProgressCount = document.createElement 'div'
      pollProgressCount.setAttribute 'class', '_pi_pollProgressCount'
      pollProgressCount.innerHTML = "(#{formattedResultCount} responses)"

      pollProgress.appendChild(pollProgressPercentage)
      pollProgress.appendChild(pollProgressCount)

      #pollProgress.innerHTML = "#{resultPercentage}% (#{resultCount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")} responses)"

      # name
      pollName = document.createElement 'div'
      pollName.setAttribute 'class', '_pi_pollName'
      pollName.setAttribute 'tabindex', '0'
      pollName.setAttribute 'role', 'heading'
      pollName.innerHTML = self.formatText(result.content)

      pollChoice.appendChild(pollText)
      pollContainer.appendChild(pollName)
      pollContainer.appendChild(pollChoice)
      pollContainer.appendChild(pollProgress)
      pollContainer.style.transition = 'all .3s cubic-bezier(0.5,1.2,.5,1.2)'

      @widgetContent.appendChild pollContainer

    # add width style to trigger css animation
    setTimeout ->
      for pollChart in document.getElementsByClassName("_pi_pollChart")
        percent = pollChart.getAttribute 'data-percent'
        pollChart.style.width = "#{percent}%"
    , 100

    @renderedResults = true
    this.setFocusAfterLoad()

  renderCustomContentThankYou: ->
    this.question = @custom_content_thank_you
    this.renderCurrentQuestion()

  renderBasicThankYou: ->
    this.focusOnLoadingInterstitial()

    @widgetContent.innerHTML = ""

    thankYouSurvey = document.createElement 'div'
    thankYouSurvey.setAttribute 'class', '_pi_thankYouSurvey'
    thankYouSurvey.innerHTML = this.formatText(this.thankYouText())
    thankYouSurvey.setAttribute 'tabindex', '0'

    @widgetContent.appendChild thankYouSurvey

    setTimeout ->
      window.PulseInsightsObject.survey.submitSurveyClosed()
      window.PulseInsightsObject.triggerOnCompleteCallback()
      window.PulseInsightsObject.survey.tearDownWidget()
    , 2000
    true

    @renderedThankYou = true
    this.setFocusAfterLoad()

  renderThankYou: ->
    if @custom_content_thank_you
      this.renderCustomContentThankYou()
    else
      this.renderBasicThankYou()

  handleAdditionalText: (questionElement, possibleAnswersContainer) ->
    return unless @question.question_type == 'single_choice_question' && @question.button_type == 1

    if this.questionHasBeforeText()
      beforeQuestion = document.createElement 'div'
      beforeQuestion.setAttribute 'class', "_pi_header pi_header_before"
      beforeQuestion.setAttribute 'id', "_pi_header_before_#{@question.id}"
      beforeQuestion.innerHTML = DOMPurify.sanitize @question.before_question_text

      questionElement.parentNode.insertBefore(beforeQuestion, questionElement)

    if this.questionHasAfterText()
      afterQuestion = document.createElement 'div'
      afterQuestion.setAttribute 'class', '_pi_header pi_header_after'
      afterQuestion.setAttribute 'id', "_pi_header_after_#{@question.id}"
      afterQuestion.innerHTML = DOMPurify.sanitize @question.after_question_text

      questionElement.parentNode.insertBefore(afterQuestion, questionElement.nextSibling)

    if parseInt(@question.before_answers_count) > 0
      scaleContainerBefore = document.createElement 'div'
      scaleContainerBefore.setAttribute 'class', '_pi_scale_container _pi_scale_container_before'
      scaleContainerBefore.setAttribute 'data-scale-items', @question.before_answers_count

      for before_answers_item, index in JSON.parse(@question.before_answers_items)
        beforeItem = document.createElement 'div'
        # set first class if if more than 1 item and is the first
        if (index == 0 && parseInt(@question.before_answers_count) >= 2)
          beforeItem.setAttribute 'class', '_pi_scale _pi_scale_first'
        # set middle class if only 1 item or more than 2 and not first or last item
        if (index == 0 && parseInt(@question.before_answers_count) == 1) || (index != 0 && (index != parseInt(@question.before_answers_count) - 1) && parseInt(@question.before_answers_count) >= 3)
          beforeItem.setAttribute 'class', '_pi_scale _pi_scale_middle'
        # set last class if more than 1 item and is the last
        if ((index == parseInt(@question.before_answers_count) - 1) && parseInt(@question.before_answers_count) >= 2)
          beforeItem.setAttribute 'class', '_pi_scale _pi_scale_last'
        beforeItem.innerHTML = JSON.parse(@question.before_answers_items)[index]
        scaleContainerBefore.appendChild(beforeItem)
      possibleAnswersContainer.parentNode.insertBefore(scaleContainerBefore, possibleAnswersContainer)
    if parseInt(@question.after_answers_count) > 0
      scaleContainerAfter = document.createElement 'div'
      scaleContainerAfter.setAttribute 'class', '_pi_scale_container _pi_scale_container_after'
      scaleContainerAfter.setAttribute 'data-scale-items', @question.after_answers_count

      for after_answers_item, index in JSON.parse(@question.after_answers_items)
        afterItem = document.createElement 'div'
        # set first class if if more than 1 item and is the first
        if (index == 0 && parseInt(@question.after_answers_count) >= 2)
          afterItem.setAttribute 'class', '_pi_scale _pi_scale_first'
        # set middle class if only 1 item or more than 2 and not first or last item
        if (index == 0 && parseInt(@question.after_answers_count) == 1) || (index != 0 && (index != parseInt(@question.after_answers_count) - 1) && parseInt(@question.after_answers_count) >= 3)
          afterItem.setAttribute 'class', '_pi_scale _pi_scale_middle'
        # set last class if more than 1 item and is the last
        if ((index == parseInt(@question.after_answers_count) - 1) && parseInt(@question.after_answers_count) >= 2)
          afterItem.setAttribute 'class', '_pi_scale _pi_scale_last'
        afterItem.innerHTML = JSON.parse(@question.after_answers_items)[index]
        scaleContainerAfter.appendChild(afterItem)
      possibleAnswersContainer.parentNode.insertBefore(scaleContainerAfter, possibleAnswersContainer.nextSibling)


# The survey should be recent (after the feature has been deployed) and the current question should be a single choice with standard buttons
  displayFlexDisplay: ->
    new Date(@question.created_at * 1000) > new Date('2019-04-08') && @question.question_type == 'single_choice_question' && @question.button_type == 1

  # TODO: Make this into a function of @question
  questionHasBeforeText: ->
    @question.before_question_text != null && @question.before_question_text.length > 0

  # TODO: Make this into a function of @question
  questionHasAfterText: ->
    @question.after_question_text != null && @question.after_question_text.length > 0

  renderCSS: ->
    this.insertCSS(this.cssStyle())

  renderThemeCss: ->
    unless @attributes["theme_css"]?
      return false

    this.insertCSS @attributes["theme_css"]

  renderCustomCSS: ->
    unless @attributes["custom_css"]?
      return false

    this.insertCSS @attributes["custom_css"]

  removeCss: (klass) ->
    css = document.querySelector(".#{klass}")
    css.parentNode.removeChild(css) if css

  insertCSS: (cssText, klass) ->
    css = document.createElement('style')
    css.type = "text/css"
    class_name = "survey-#{this.id()}"
    class_name += " #{klass}" if klass
    css.className = class_name
    if (css.styleSheet)
      css.styleSheet.cssText = cssText
    else
      css.appendChild(document.createTextNode(cssText))

    body = document.getElementsByTagName('body')[0]
    body.appendChild(css)

  insertWidgetContainer: (widgetContainer, widgetParent, renderPosition) ->
    if renderPosition == "below"
      widgetParent.appendChild widgetContainer
    else if renderPosition == "above"
      widgetParent.insertBefore widgetContainer, widgetParent.childNodes[0]
    else if renderPosition == "before"
      widgetParent.parentElement.insertBefore widgetContainer, widgetParent
    else if renderPosition == "after"
      widgetParent.parentElement.insertBefore(widgetContainer, widgetParent.nextSibling)
