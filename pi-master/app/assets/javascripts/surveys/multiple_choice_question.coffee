# Code specific to the handling of multiple choices questions

window.PulseInsightsInclude window.Survey,
  renderMultipleChoicesQuestion: (possibleAnswersContainer, display_all_questions) ->
    questionId = @question.id

    self = this
    is_mobile = window.PulseInsightsObject.isMobile() && (@attributes["survey_type"]!=1 && @attributes["survey_type"]!=3)

    for possibleAnswer in @question.possible_answers
      do (possibleAnswer) ->
        possibleAnswerElement = document.createElement 'li'
        possibleAnswerElement.setAttribute 'data-possible-answer-locale-group-id', possibleAnswer.possible_answer_locale_group_id

        # Create checkbox
        checkBox = document.createElement 'input'
        checkBox.setAttribute 'class', '_pi_checkbox'
        checkBox.setAttribute 'type', 'checkbox'
        checkBox.setAttribute 'value', possibleAnswer.id
        checkBox.setAttribute 'aria-describedby', self.multipleChoiceAriaDescribedByIds(questionId)

        checkBoxControl = document.createElement 'div'
        checkBoxControl.setAttribute 'class', '_pi-control-indicator'

        # Create label and preprend checkbox
        possibleAnswerLabelElement = document.createElement 'label'
        possibleAnswerLabelElement.setAttribute 'class', '_pi-control _pi-control-checkbox'
        possibleAnswerLabelElement.innerHTML = window.PulseInsightsObject.survey.formatText(possibleAnswer.content)

        possibleAnswerLabelElement.insertBefore(checkBoxControl, possibleAnswerLabelElement.firstChild)
        possibleAnswerLabelElement.insertBefore(checkBox, possibleAnswerLabelElement.firstChild)
        checkBox.addEventListener('click', PulseInsightsObject.survey.multipleChoicesCheckboxClicked)
        # Add the label and checkbox to <li>
        possibleAnswerElement.appendChild possibleAnswerLabelElement
        # Add <li> element to <ul> list
        possibleAnswersContainer.appendChild possibleAnswerElement

        per_row = if is_mobile then self.question.answers_per_row_mobile else self.question.answers_per_row_desktop
        if per_row
          possibleAnswerElement.setAttribute 'style', "max-width: calc(#{100 / per_row}% - 20px);"

    # Create label container
    textInputContainer = document.createElement 'div'
    textInputContainer.setAttribute 'class', '_pi_free_text_question_field_container'
    possibleAnswersContainer.appendChild textInputContainer

    # Create choices count label
    @choicesCountLabel = document.createElement 'div'
    @choicesCountLabel.setAttribute 'id', "_pi_multiple_choices_question_#{questionId}_count"
    @choicesCountLabel.setAttribute 'class', '_pi_multiple_choices_count'

    if self.isAllAtOnce() && self.allAtOnceEmptyErrorEnabled()
      # Create alert label container
      alertLabelContainer = document.createElement 'div'
      alertLabelContainer.setAttribute 'class', '_pi_multiple_choice_question_alert_label_container'

      # Create empty answer alert label
      @emptyAnswerAlertLabel = document.createElement 'div'
      @emptyAnswerAlertLabel.setAttribute 'id', "_pi_multiple_choices_question_#{questionId}_empty_answer"
      @emptyAnswerAlertLabel.setAttribute 'class', '_pi_multiple_choices_empty_answer_alert'
      @emptyAnswerAlertLabel.setAttribute 'data-alert-text', @question.empty_error_text

      textInputContainer.appendChild alertLabelContainer
      alertLabelContainer.appendChild @choicesCountLabel
      alertLabelContainer.appendChild @emptyAnswerAlertLabel
    else
      textInputContainer.appendChild @choicesCountLabel

    # Create submit button and then add to the possibleAnswerContainer
    submitButtonContainer = document.createElement 'div'

    unless display_all_questions
      submitButtonContainer.setAttribute 'class', '_pi_multiple_choices_question_submit_button_container'

      submitButton = document.createElement 'input'
      submitButton.setAttribute 'class', '_pi_multiple_choices_question_submit_button'
      submitButton.setAttribute 'type', 'submit'
      submitButton.setAttribute 'value', (@question.submit_label || "Submit")
      submitButton.setAttribute 'aria-disabled', 'false'
      submitButton.onclick = window.PulseInsightsObject.survey.multipleChoicesSubmitClicked

      submitButtonError = document.createElement 'div'
      submitButtonError.setAttribute 'data-alert-text', @question.empty_error_text
      submitButtonError.setAttribute 'class', '_pi_multiple_choices_question_submit_error'
      submitButtonError.setAttribute 'role', 'alert'

      submitButtonContainer.appendChild submitButton
      submitButtonContainer.appendChild submitButtonError

    possibleAnswersContainer.appendChild submitButtonContainer

  multipleChoicesSubmitClicked: (event) ->
    event.stopPropagation()
    window.PulseInsightsObject.survey.setControlTransitionFocus(window.PulseInsightsObject.survey.shouldControlFocus(event))

    questionId = window.PulseInsightsObject.survey.question.id
    answerIds = window.PulseInsightsObject.survey.multipleChoiceAnswerIds(questionId)

    answerContainer = event.target.closest('._pi_answers_container')

    maximumSelection = window.PulseInsightsObject.survey.question.maximum_selection if window.PulseInsightsObject.survey.question.maximum_selection?

    params =
      identifier: window.PulseInsightsObject.identifier
      question_id: questionId
      check_boxes: answerIds

    if answerIds.length == 0
      submitButtonError = answerContainer.querySelector('._pi_multiple_choices_question_submit_error')
      window.PulseInsightsObject.survey.updateSubmitButtonError submitButtonError
      return false

    return false if maximumSelection? && (answerIds.length > maximumSelection)

    if window.PulseInsightsObject.submission?
      submissionUdid = window.PulseInsightsObject.submission.udid
    else
      submissionUdid = null

    # If there's custom data, send it along with the answer because
    #  it may have changed since the call to get the survey.
    if window.PulseInsightsObject.customData?
      params['custom_data'] = window.PulseInsightsObject.stringify(window.PulseInsightsObject.customData)

    if window.PulseInsightsObject.client_key
      params['client_key'] = window.PulseInsightsObject.getClientKey()

    if window.PulseInsightsObject.previewMode
      window.PulseInsightsObject.survey.answersSubmitted()
      return false

    window.PulseInsightsObject.triggerOnAnswerCallback(event)
    window.PulseInsightsObject.jsonpGet "/submissions/#{submissionUdid}/answer", params, window.PulseInsightsObject.survey.answersSubmitted
    false

  multipleChoicesCheckboxClicked: (event) ->
    event.stopPropagation()

    window.PulseInsightsObject.survey.setControlTransitionFocus(window.PulseInsightsObject.survey.shouldControlFocus(event))

    survey = window.PulseInsightsObject.survey
    choicesCountLabel = survey.choicesCountLabel

    answerContainer = event.target.closest('._pi_answers_container')
    questionId = parseInt(answerContainer.getAttribute('data-question-id'))
    answerIds = survey.multipleChoiceAnswerIds(questionId)

    if survey.isAllAtOnce()
      questionId = parseInt(answerContainer.getAttribute('data-question-id'))
      for question in survey.questions
        if question.id == questionId
          maximumSelection = question.maximum_selection if question.maximum_selection?
    else
      maximumSelection = survey.question.maximum_selection if survey.question.maximum_selection?

    if this.checked
      answerIds.push this.value

      if survey.isAllAtOnce() && survey.allAtOnceEmptyErrorEnabled() && !survey.isQuestionOptional(answerContainer)
        survey.removeMultipleChoiceEmptyAnswerAlert answerContainer
        survey.setMultipleChoicesAriaInvalid answerContainer, 'false'

      if maximumSelection? && (answerIds.length > maximumSelection)
        customErrorText = survey.question.maximum_selections_exceeded_error_text
        choicesLabelText = customErrorText || "Maximum of #{maximumSelection} please."
        charactersCountLabelTextNode = document.createTextNode choicesLabelText
        choicesCountLabel.innerHTML = ""
        choicesCountLabel.appendChild charactersCountLabelTextNode
        choicesCountLabel.setAttribute 'role', 'alert'
        window.PulseInsightsObject.survey.setSubmitButtonAriaDisabled('true')
        window.PulseInsightsObject.survey.setMultipleChoicesAriaInvalid answerContainer, 'true'
    else
      answerIds = answerIds.filter((answerId) => answerId != this.value)

      if maximumSelection? && (answerIds.length <= maximumSelection)
        choicesLabelText = ""
        charactersCountLabelTextNode = document.createTextNode choicesLabelText
        choicesCountLabel.innerHTML = ""
        choicesCountLabel.appendChild charactersCountLabelTextNode
        choicesCountLabel.removeAttribute 'role', ''
        window.PulseInsightsObject.survey.setSubmitButtonAriaDisabled('false')
        window.PulseInsightsObject.survey.setMultipleChoicesAriaInvalid answerContainer, 'false'

    answerContainer.setAttribute 'data-answer', answerIds

    # Add "data-answer-content" to answerContainer
    question = survey.questions.find (question) -> question.id == questionId
    answerContents = answerIds.map (selectedAnswerId) ->
      selectedAnswer = question.possible_answers.find (possibleAnswer) -> possibleAnswer.id == parseInt(selectedAnswerId)
      selectedAnswer.content
    answerContainer.setAttribute 'data-answer-content', answerContents.join()

    if survey.isAllAtOnce()
      survey.checkSubmissionCompleteness answerContainer
    else if answerIds.length > 0
      survey.removeSubmitButtonError answerContainer

  multipleChoiceAnswerIds: (questionId) ->
    answerContainer = document.querySelector("._pi_answers_container[data-question-id='#{questionId}'")
    answerProperty = answerContainer.dataset.answer
    if answerProperty then answerProperty.split(',') else []

  multipleChoiceAriaDescribedByIds: (questionId) ->
    if this.isAllAtOnce() && this.allAtOnceEmptyErrorEnabled()
      "_pi_multiple_choices_question_#{questionId}_empty_answer _pi_multiple_choices_question_#{questionId}_count"
    else
      "_pi_multiple_choices_question_#{questionId}_count"

  # TODO: Something more robust than this
  setSubmitButtonAriaDisabled: (newVal) ->
    submitButton = document.getElementsByClassName('_pi_multiple_choices_question_submit_button')[0]
    submitButton.setAttribute 'aria-disabled', newVal if submitButton

  removeMultipleChoiceEmptyAnswerAlert: (answerContainer) ->
    emptyAnswerAlertLabel = answerContainer.querySelector('._pi_multiple_choices_empty_answer_alert')
    emptyAnswerAlertLabel.innerText = ''

  addMultipleChoiceEmptyAnswerAlert: (answerContainer) ->
    emptyAnswerAlertLabel = answerContainer.querySelector('._pi_multiple_choices_empty_answer_alert')
    emptyAnswerAlertLabel.innerText = emptyAnswerAlertLabel.getAttribute('data-alert-text')

  setMultipleChoicesAriaInvalid: (answerContainer, value) ->
    # The first checkbox is the element to focus on for accessibility when submit fails
    firstCheckBox = answerContainer.querySelector('._pi_checkbox')
    firstCheckBox.setAttribute 'aria-invalid', value

  removeSubmitButtonError: (answerContainer) ->
    submitButtonError = answerContainer.querySelector('._pi_multiple_choices_question_submit_error')
    submitButtonError.innerHTML = ''

  updateSubmitButtonError: (submitButtonError) ->
    if submitButtonError.innerHTML == ''
      submitButtonError.innerHTML = submitButtonError.getAttribute('data-alert-text')
    else
      # If the error message is already displayed, a screen reader will be triggered by
      # appending a hidden error element
      window.PulseInsightsObject.survey.appendScreenReaderSubmitButtonError submitButtonError

  appendScreenReaderSubmitButtonError: (submitButtonError) ->
    submitButtonContainer = submitButtonError.parentNode

    screenReaderSubmitButtonError = document.createElement 'div'
    screenReaderSubmitButtonError.setAttribute 'class', '_pi_screen_reader_only'
    screenReaderSubmitButtonError.setAttribute 'role', 'alert'
    screenReaderSubmitButtonError.setAttribute 'aria-relevant', 'additions'
    screenReaderSubmitButtonError.innerHTML = submitButtonError.innerHTML

    submitButtonContainer.appendChild screenReaderSubmitButtonError

  multipleChoiceAlertContainerClass: ->
    if this.isAllAtOnce() && this.allAtOnceEmptyErrorEnabled()
      "_pi_multiple_choice_question_alert_label_container"
    else
      "_pi_multiple_choices_count"

  multipleChoicesQuestionCSS: ->
    "
      ._pi-control {
        display: block;
        position: relative;
        margin: 0px 0px 0px 25px;
        padding: 5px 0px 5px 0px;
      }

      ._pi-control input {
        position: absolute;
        z-index: -1;
        opacity: 0;
      }

      ._pi-control-indicator {
        position: absolute;
        top: 9px;
        left: -25px;
        height: 15px;
        width: 15px;
        border: 1px solid rgba(255,255,255,0.5);
      }

      ._pi-control-indicator:after {
        content: '';
        position: absolute;
        display: none;
      }

      ._pi-control input:checked ~ ._pi-control-indicator:after {
        display: block;
      }

      ._pi-control-checkbox ._pi-control-indicator:after {
        left: 4px;
        width: 5px;
        height: 11px;
        border: solid rgba(255,255,255,0.5);
        border-width: 0 2px 2px 0;
        transform: rotate(45deg);
      }

      div._pi_free_text_question_field_container {
        clear: both;
        margin: 0px 18px 10px 18px;
      }

      ul._pi_answers_container li label input._pi_checkbox {
        margin-right: 10px;
        cursor: pointer;
      }

      ul._pi_answers_container li label {
        color: #{this.answerTextColor()};
        #{this.fontCSS()}
        width: 100%;
        width: -moz-calc(100% - 35px);
        width: -webkit-calc(100% - 35px);
        width: calc(100% - 35px);
        float: left;
        cursor: pointer;
      }

      div._pi_multiple_choices_question_submit_button_container {
        margin: 10px 0px 0px 0px;
        clear: both;
      }

      input._pi_multiple_choices_question_submit_button {
        background-color: black;
        font-size: 15px;
        padding: 5px 20px;
        border: none;
        color: #eaf4fb;
        cursor: pointer;
      }

      input._pi_multiple_choices_question_submit_button:hover {
        background-color: #101010;
      }

      input._pi_multiple_choices_question_submit_button:disabled {
        opacity: 0.3;
      }

      input._pi_multiple_choices_question_submit_button:hover:disabled {
        background-color: black;
        opacity: 0.3;
      }

      .#{this.multipleChoiceAlertContainerClass()} {
        #{this.fontCSS()};
        font-size: 12px;
        color: #927a85;
        height: 17px;
      }

      ._pi_multiple_choices_question_submit_error {
        #{this.fontCSS()};
        text-align: center;
        font-size: 12px;
        color: #927a85;
        margin-top: 10px;
      }
    "
