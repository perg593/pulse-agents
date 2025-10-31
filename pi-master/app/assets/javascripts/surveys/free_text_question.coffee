# Code specific to the handling of free text questions

window.PulseInsightsInclude window.Survey,
  renderFreeTextQuestion: (possibleAnswersContainer, display_all_question = false) ->
    @textInputContainer = document.createElement 'div'
    @textInputContainer.setAttribute 'class', '_pi_free_text_question_field_container'
    @maxLength = @question.max_length

    if @question.height < 2
      # Add text field
      @textInput = document.createElement 'input'
      @textInput.setAttribute 'type', 'text'
    else
      # Add text area
      @textInput = document.createElement 'textarea'
      @textInput.setAttribute 'rows', @question.height
      @textInput.setAttribute 'cols', 20

    @textInput.setAttribute 'class', '_pi_free_text_question_field'
    @textInput.setAttribute 'maxlength', @maxLength
    @textInput.setAttribute 'placeholder', @question.hint_text
    @textInput.setAttribute 'data-max-length', @question.max_length
    @textInput.setAttribute 'aria-labelledby', "_pi_question_#{@question.id}"
    @textInput.setAttribute 'aria-required', 'true' if @question.optional == 'f'
    @textInput.setAttribute 'aria-describedby', this.freeTextAriaDescribedByIds(@question.id)

    # Create label container
    @labelContainer = document.createElement 'div'
    @labelContainer.setAttribute 'class', '_pi_free_text_question_label_container'

    # Create personal data alert label
    @personalDataAlertLabel = document.createElement 'div'
    @personalDataAlertLabel.setAttribute 'data-alert-text', @question.error_text
    @personalDataAlertLabel.setAttribute 'id', "_pi_question_#{@question.id}_personal_data_alert"
    @personalDataAlertLabel.setAttribute 'class', '_pi_free_text_question_personal_data_alert'

    # Create characters count label
    @charactersCountLabel = document.createElement 'div'
    @charactersCountLabel.setAttribute 'class', '_pi_free_text_question_characters_count'

    # Create screen reader characters count label
    @screenReaderCharactersCountLabel = document.createElement 'div'
    @screenReaderCharactersCountLabel.setAttribute 'id', '_pi_free_text_question_screen_reader_characters_count'
    @screenReaderCharactersCountLabel.setAttribute 'class', '_pi_screen_reader_only'
    @screenReaderCharactersCountLabel.setAttribute 'aria-live', 'polite'
    @screenReaderCharactersCountLabel.setAttribute 'aria-atomic', 'true'

    possibleAnswersContainer.appendChild @textInputContainer
    @textInputContainer.appendChild @textInput
    @textInputContainer.appendChild @labelContainer

    if this.isAllAtOnce() && this.allAtOnceEmptyErrorEnabled()
      # Create alert label container
      @alertLabelContainer = document.createElement 'div'
      @alertLabelContainer.setAttribute 'class', '_pi_free_text_question_alert_label_container'

      # Create empty answer alert label
      @emptyAnswerAlertLabel = document.createElement 'div'
      @emptyAnswerAlertLabel.setAttribute 'data-alert-text', @question.empty_error_text
      @emptyAnswerAlertLabel.setAttribute 'class', '_pi_free_text_question_empty_answer_alert'
      @emptyAnswerAlertLabel.setAttribute 'id', "_pi_question_#{@question.id}_empty_answer_alert"

      @alertLabelContainer.appendChild @emptyAnswerAlertLabel
      @alertLabelContainer.appendChild @personalDataAlertLabel

      @labelContainer.appendChild @alertLabelContainer
      @labelContainer.appendChild @charactersCountLabel
      @labelContainer.appendChild @screenReaderCharactersCountLabel
    else
      @labelContainer.appendChild @personalDataAlertLabel
      @labelContainer.appendChild @charactersCountLabel
      @labelContainer.appendChild @screenReaderCharactersCountLabel

    @installEventOnFreeTextInput(@textInput)

    submitButtonContainer = document.createElement 'div'
    submitButtonContainer.setAttribute 'class', '_pi_free_text_question_submit_button_container'

    @submitButton = document.createElement 'input'

    unless display_all_question
      @submitButton.setAttribute 'class', '_pi_free_text_question_submit_button'
      @submitButton.setAttribute 'type', 'submit'
      @submitButton.setAttribute 'value', (@question.submit_label || "Submit")
      @submitButton.onclick = window.PulseInsightsObject.survey.freeTextSubmitClicked

      submitButtonContainer.appendChild @submitButton

    possibleAnswersContainer.appendChild submitButtonContainer
    @updateCharactersCountLabel(@textInput)

    addFocusClass = (e) ->
      classes = window.PulseInsightsObject.survey.widgetContainer.getAttribute 'class'
      classes = classes + " text-input-focus"
      window.PulseInsightsObject.survey.widgetContainer.setAttribute 'class', classes

    removeFocusClass = (e) ->
      classes = window.PulseInsightsObject.survey.widgetContainer.getAttribute 'class'
      classes = classes.replace('text-input-focus', '')
      window.PulseInsightsObject.survey.widgetContainer.setAttribute 'class', classes

    @textInput.addEventListener('focus', addFocusClass)
    @textInput.addEventListener('blur', removeFocusClass)

    if this.isAllAtOnce() && this.allAtOnceEmptyErrorEnabled() && @question.optional == 'f'
      @textInput.addEventListener 'keyup', () ->
        window.PulseInsightsObject.survey.removeFreeTextEmptyAnswerAlert(this)

    if this.personalDataMaskingEnabled()
      @textInput.addEventListener 'keyup', () ->
        window.PulseInsightsObject.survey.togglePersonalDataAlert(this)

  installEventOnFreeTextInput: (input) ->
    textInputChanged = window.PulseInsightsObject.survey.textInputChanged

    textInputChangedForScreenReader = window.PulseInsightsInclude.debounce(window.PulseInsightsObject.survey.textInputChangedForScreenReader, 2000)

    if input.addEventListener
      input.addEventListener 'keypress', textInputChanged
      input.addEventListener 'keypress', textInputChangedForScreenReader
      input.addEventListener 'keyup', textInputChanged
      input.addEventListener 'keyup', textInputChangedForScreenReader
    else if input.attachEvent
      input.attachEvent 'onkeypress', textInputChanged
      input.attachEvent 'onkeypress', textInputChangedForScreenReader
      input.attachEvent 'onkeyup', textInputChanged
      input.attachEvent 'onkeyup', textInputChangedForScreenReader
    else
      input['onkeypress'] = textInputChanged
      input['onkeypress'] = textInputChangedForScreenReader
      input['onkeyup'] = textInputChanged
      input['onkeyup'] = textInputChangedForScreenReader

  freeTextSubmitClicked: (event) ->
    window.PulseInsightsObject.survey.setControlTransitionFocus(window.PulseInsightsObject.survey.shouldControlFocus(event))

    textAnswer = window.PulseInsightsObject.survey.textInput.value

    questionId = window.PulseInsightsObject.survey.question.id
    params =
      identifier: window.PulseInsightsObject.identifier
      question_id: questionId
      text_answer: textAnswer

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

    if window.PulseInsightsObject.previewMode || textAnswer.length == 0
      window.PulseInsightsObject.survey.answersSubmitted()
      return false

    window.PulseInsightsObject.triggerOnAnswerCallback(event)
    window.PulseInsightsObject.jsonpGet "/submissions/#{submissionUdid}/answer", params, window.PulseInsightsObject.survey.answersSubmitted
    false

  textInputChanged: (event) ->
    # Update the characters count labels
    survey = window.PulseInsightsObject.survey
    survey.updateCharactersCountLabel.apply survey, [event.target]

  textInputChangedForScreenReader: (event) ->
    survey = window.PulseInsightsObject.survey
    survey.updateScreenReaderCharactersCountLabel.apply survey, [event.target]

  updateCharactersCountLabel: (input) ->
    maxLength = input.getAttribute('data-max-length')

    if maxLength == 0
      return

    charactersCountLabel = input.parentNode.querySelector('._pi_free_text_question_characters_count')
    answerLength = input.value.length
    charactersCountLabelTextContent = this.charactersCountLabelTextContent answerLength, maxLength, false
    this.updateCharactersCountLabelText charactersCountLabel, charactersCountLabelTextContent

    # Set the data to send to the Rack app
    answerContainer = event.target.parentNode.parentNode if event && event.target && event.target.parentNode
    answerContainer.setAttribute('data-answer', event.target.value) if answerContainer

    remainingCharacters = maxLength - answerLength

    if remainingCharacters > 0
      # Add 'danger' class if the count is close to limit
      charactersCountLabel.setAttribute 'class', "_pi_free_text_question_characters_count #{'danger' if remainingCharacters < 20}"
      # Make sure the submit button is enabled
      @submitButton.removeAttribute 'disabled'
      @submitButton.setAttribute 'aria-disabled', 'false'
      @textInput.setAttribute 'aria-invalid', 'false'
    else if remainingCharacters == 0
      event.preventDefault() if event && (event.keyCode not in [46, 8]) # delete key and backspace
    else
      # Disable the button
      @submitButton.setAttribute 'disabled', 'disabled'
      @submitButton.setAttribute 'aria-disabled', 'true'
      # Prevent sending data to the Rack app
      answerContainer.setAttribute('data-answer', '') if answerContainer
      @textInput.setAttribute 'aria-invalid', 'true'

    if this.attributes.display_all_questions == 't'
      this.checkSubmissionCompleteness answerContainer if answerContainer
    else
      this.toggleSubmitButton()

  updateScreenReaderCharactersCountLabel: (input) ->
    maxLength = input.getAttribute('data-max-length')

    if maxLength == 0
      return

    answerLength = input.value.length
    screenReaderCharactersCountLabel = input.parentNode.querySelector('#_pi_free_text_question_screen_reader_characters_count')
    charactersCountLabelTextContent = this.charactersCountLabelTextContent answerLength, maxLength, true
    this.updateCharactersCountLabelText screenReaderCharactersCountLabel, charactersCountLabelTextContent

  updateCharactersCountLabelText: (charactersCountLabel, textContent) ->
    charactersCountLabelTextNode = document.createTextNode textContent
    charactersCountLabel.innerHTML = ""
    charactersCountLabel.appendChild charactersCountLabelTextNode

  charactersCountLabelTextContent: (answerLength, maxLength, isScreenReader) ->
    if isScreenReader
      "You have used #{answerLength} characters of #{maxLength}"
    else
      "#{answerLength}/#{maxLength}"

  toggleSubmitButton: ->
    answerLength = @textInput.value.length
    maxLength = @textInput.getAttribute('data-max-length')

    # characters are still left, or personal data is detected when it's not allowd
    if (maxLength - answerLength) < 0 || (this.personalDataMaskingEnabled() && this.detectPersonalData(@textInput.value))
      @submitButton.setAttribute('disabled', 'disabled')
      @submitButton.setAttribute 'aria-disabled', 'true'
      @textInput.setAttribute 'aria-invalid', 'true'
    else
      @submitButton.removeAttribute('disabled')
      @submitButton.setAttribute 'aria-disabled', 'false'
      @textInput.setAttribute 'aria-invalid', 'false'

  togglePersonalDataAlert: (textInput) ->
    personalDataAlertLabel = textInput.parentNode.querySelector('._pi_free_text_question_personal_data_alert')
    if this.detectPersonalData(textInput.value)
      personalDataAlertLabel.innerText = personalDataAlertLabel.getAttribute('data-alert-text')
      personalDataAlertLabel.setAttribute 'role', 'alert'
      textInput.setAttribute 'aria-invalid', 'true'
    else
      personalDataAlertLabel.innerText = ''
      personalDataAlertLabel.removeAttribute 'role'
      textInput.setAttribute 'aria-invalid', 'false'

  removeFreeTextEmptyAnswerAlert: (textInput) ->
    answerLength = textInput.value.length
    emptyAnswerAlertLabel = textInput.parentNode.querySelector('._pi_free_text_question_empty_answer_alert')

    if answerLength > 0
      emptyAnswerAlertLabel.innerText = ''
      textInput.setAttribute 'aria-invalid', 'false'

  detectPersonalData: (text) ->
    return if text == ''

    # Social Security Number -> https://stackoverflow.com/a/7067903/12065544
    ssnRegex   = /(^|\s)\d{3}-\d{2}-\d{4}($|\s)/
    # UK National Insurance -> https://stackoverflow.com/a/17779536/12065544
    niRegex    = /(^|\s)(?!BG)(?!GB)(?!NK)(?!KN)(?!TN)(?!NT)(?!ZZ)(?:[A-CEGHJ-PR-TW-Z][A-CEGHJ-NPR-TW-Z])(?:\s*\d\s*){6}([A-D]|\s)/i
    # https://stackoverflow.com/a/17767762/12065544
    phoneRegex = /(^|\s|\+)\d{2}[\s\d-]{6,}($|\s)/
    # https://stackoverflow.com/a/42408099/12065544
    emailRegex = /(^|\s)([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+)($|\s)/

    detected  = ssnRegex.test(text) | niRegex.test(text)
    detected |= phoneRegex.test(text) if this.attributes['phone_number_masked']
    detected |= emailRegex.test(text) if this.attributes['email_masked']
    detected

  personalDataMaskingEnabled: ->
    this.attributes['personal_data_masking_enabled']

  addFreeTextEmptyAnswerAlert: (answerContainer) ->
    emptyAnswerAlertLabel = answerContainer.querySelector('._pi_free_text_question_empty_answer_alert')
    emptyAnswerAlertLabel.innerText = emptyAnswerAlertLabel.getAttribute('data-alert-text')

  setFreeTextAriaInvalid: (answerContainer) ->
    textInput = answerContainer.querySelector('._pi_free_text_question_field')
    textInput.setAttribute 'aria-invalid', 'true'

  freeTextAriaDescribedByIds: (questionId) ->
    if this.isAllAtOnce() && this.allAtOnceEmptyErrorEnabled()
      "_pi_question_#{questionId}_personal_data_alert _pi_question_#{questionId}_empty_answer_alert"
    else
      "_pi_question_#{questionId}_personal_data_alert"

  freeTextAlertContainerCSS: ->
    if this.isAllAtOnce() && this.allAtOnceEmptyErrorEnabled()
      "
        ._pi_free_text_question_alert_label_container {
          #{this.fontCSS()};
          font-size: 12px;
          color: #927a85;
          overflow: hidden;
        }

        ._pi_free_text_question_personal_data_alert, ._pi_free_text_question_empty_answer_alert {
          overflow: hidden;
          text-overflow: ellipsis;
        }
      "
    else
      "
        ._pi_free_text_question_personal_data_alert {
          #{this.fontCSS()};
          font-size: 12px;
          color: #927a85;
          overflow: hidden;
          text-overflow: ellipsis;
        }
      "

  freeTextQuestionCSS: ->
    "
      div._pi_free_text_question_field_container {
        margin: 0px 18px 10px 18px;
      }

      input._pi_free_text_question_field, textarea._pi_free_text_question_field {
        #{this.fontCSS()};
        width: 100%;
        padding: 0px 2px;
        border: none;
        border-bottom: 1px solid #57636e;
        background-color: transparent;
        outline: none;
        box-shadow: none;
        font-size: 15px;
        color: #ccd1dd;
      }

      textarea._pi_free_text_question_field {
        border: 1px solid #57636e;
      }

      input._pi_free_text_question_field:hover, textarea._pi_free_text_question_field:hover {
        border-bottom: 1px solid #8fa9b6;
      }

      textarea._pi_free_text_question_field:hover {
        border: 1px solid #8fa9b6;
      }

      div._pi_free_text_question_submit_button_container {
        margin: 10px 0px 0px 0px;
      }

      input._pi_free_text_question_submit_button {
        background-color: black;
        font-size: 15px;
        padding: 5px 20px;
        border: none;
        color: #eaf4fb;
        cursor: pointer;
      }

      input._pi_free_text_question_submit_button:hover {
        background-color: #101010;
      }

      input._pi_free_text_question_submit_button:disabled {
        opacity: 0.3;
      }

      input._pi_free_text_question_submit_button:hover:disabled {
        background-color: black;
        opacity: 0.3;
      }

      ._pi_free_text_question_label_container {
        display: flex;
        justify-content: space-between;
        white-space: nowrap;
      }

      ._pi_free_text_question_characters_count {
        #{this.fontCSS()};
        font-size: 12px;
        color: #7a8992;
      }

      ._pi_free_text_question_characters_count.danger {
        color: #927a85;
      }

      #{this.freeTextAlertContainerCSS()}
    "
