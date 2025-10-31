# Code specific to the handling of slider questions

window.PulseInsightsInclude window.Survey,
  renderSliderQuestion: (possibleAnswersContainer, display_all_questions = false) ->
    sliderContainer = this.createSliderContainer(possibleAnswersContainer)
    hiddenSlider = this.createHiddenSlider(sliderContainer) # We place a hidden slider(an invisible range input) behind noUiSlider to make it screen reader compatible https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2293
    slider = this.createSlider(sliderContainer)
    submitButton = if this.hasSubmitButton() then this.createSliderSubmitButton(possibleAnswersContainer) else null

    if display_all_questions && this.allAtOnceEmptyErrorEnabled()
      this.createAllAtOnceAlertForSlider(sliderContainer)

    slider.noUiSlider.on 'change', (values, _handle, _unencoded, _tap, _positions, noUiSlider) ->
      sliderPosition = values[0]
      answerContainer = noUiSlider.getOrigins()[0].closest('._pi_answers_container')
      window.PulseInsightsObject.survey.processSliderEngagement(answerContainer, sliderPosition)

    hiddenSlider.addEventListener 'change', (e) ->
      sliderPosition = parseInt(e.target.value)
      answerContainer = e.target.closest('._pi_answers_container')
      survey = window.PulseInsightsObject.survey
      survey.moveSliderPosition(answerContainer, sliderPosition)
      survey.processSliderEngagement(answerContainer, sliderPosition)

    for pip in slider.querySelectorAll('.noUi-value') # Pip clicking feature https://refreshless.com/nouislider/examples/#section-click-pips
      do (pip) -> # Closure for variables http://coffeescript.org/#loops
        pip.addEventListener 'click', () ->
          sliderPosition = parseInt(this.getAttribute('data-value'))
          answerContainer = this.closest('._pi_answers_container')
          survey = window.PulseInsightsObject.survey
          survey.moveSliderPosition(answerContainer, sliderPosition)
          survey.processSliderEngagement(answerContainer, sliderPosition)

    if submitButton
      submitButton.addEventListener 'click', (event) ->
        if window.PulseInsightsObject.survey.shouldControlFocus(event)
          window.PulseInsightsObject.survey.setControlTransitionFocus(true)

        answerContainer = this.closest('._pi_answers_container')
        survey = window.PulseInsightsObject.survey
        if survey.sliderHasBeenEngaged(answerContainer)
          survey.submitSliderAnswer(survey.answerId)
        else
          survey.addSliderSubmitButtonError(answerContainer)
          survey.setSliderAriaInvalid(answerContainer)

  hasSubmitButton: ->
    this.attributes.display_all_questions == 'f' && this.question.slider_submit_button_enabled == 't'

  processSliderEngagement: (answerContainer, sliderPosition) ->
    this.synchronizeHiddenSlider(answerContainer, sliderPosition)
    this.markSliderAsEngaged(answerContainer)
    this.unsetSliderAriaInvalid(answerContainer)

    questionId = answerContainer.getAttribute('data-question-id')
    question = this.getQuestionById(questionId)
    answerId = this.getPossibleAnswerByPosition(question, sliderPosition).id

    if this.attributes.display_all_questions == 't'
      answerContainer.setAttribute 'data-answer', answerId # Necessary to send answers to back-end
      this.checkSubmissionCompleteness(answerContainer) # Necessary for AAO submit button to be validated
      this.removeAllAtOnceEmptyAnswerAlertForSlider(answerContainer)
    else
      this.answerId = answerId # Necessary to send answers to back-end
      if this.question.slider_submit_button_enabled == 't'
        this.removeSliderSubmitButtonError(answerContainer)
      else
        this.submitSliderAnswer(answerId)

  moveSliderPosition: (answerContainer, sliderPosition) ->
    slider = answerContainer.querySelector('._pi_slider')
    slider.noUiSlider.set(sliderPosition)

  synchronizeHiddenSlider: (answerContainer, sliderPosition) ->
    questionId = answerContainer.getAttribute('data-question-id')
    question = this.getQuestionById(questionId)
    answer = this.getPossibleAnswerByPosition(question, sliderPosition)

    hiddenSlider = answerContainer.querySelector('._pi_hidden_slider')
    hiddenSlider.setAttribute 'value', parseInt(sliderPosition)
    hiddenSlider.ariaValueNow = parseInt(sliderPosition)
    hiddenSlider.ariaValueText = answer.content

  addSliderSubmitButtonError: (answerContainer) ->
    submitButtonError = answerContainer.querySelector('._pi_slider_question_submit_button_error')
    submitButtonError.innerText = this.question.empty_error_text

  removeSliderSubmitButtonError: (answerContainer) ->
    submitButtonError = answerContainer.querySelector('._pi_slider_question_submit_button_error')
    submitButtonError.innerText = ''

  setSliderAriaInvalid: (answerContainer) ->
    hiddenSlider = answerContainer.querySelector('._pi_hidden_slider')
    hiddenSlider.setAttribute 'aria-invalid', true

  unsetSliderAriaInvalid: (answerContainer) ->
    hiddenSlider = answerContainer.querySelector('._pi_hidden_slider')
    hiddenSlider.removeAttribute 'aria-invalid'

  addAllAtOnceEmptyAnswerAlertForSlider: (answerContainer) ->
    return unless this.allAtOnceEmptyErrorEnabled()
    emptyAnswerAlertLabel = answerContainer.querySelector('._pi_all_at_once_slider_question_empty_answer_alert')
    emptyAnswerAlertLabel.innerText = emptyAnswerAlertLabel.getAttribute('data-alert-text')

  removeAllAtOnceEmptyAnswerAlertForSlider: (answerContainer) ->
    return unless this.allAtOnceEmptyErrorEnabled()
    emptyAnswerAlertLabel = answerContainer.querySelector('._pi_all_at_once_slider_question_empty_answer_alert')
    emptyAnswerAlertLabel.innerText = ''

  markSliderAsEngaged: (answerContainer) -> # This also allows theme editors to modify styles based on slider engagement
    sliderContainer = answerContainer.querySelector('._pi_slider_question_container')
    sliderContainer.classList.add 'engaged'

  sliderHasBeenEngaged: (answerContainer) ->
    sliderContainer = answerContainer.querySelector('._pi_slider_question_container')
    sliderContainer.classList.contains 'engaged'

  submitSliderAnswer: (answerId) ->
    PI = window.PulseInsightsObject

    if PI.previewMode
      this.answersSubmitted()
      return false

    submissionUdid = PI.submission?.udid || null # Avoiding "undefined" because the back-end wouldn't be able to handle it
    params = { identifier: PI.identifier, question_id: this.question.id, answer_id: answerId }
    PI.jsonpGet "/submissions/#{submissionUdid}/answer", params, this.answersSubmitted

  createSliderContainer: (containerNode) ->
    sliderContainer = document.createElement('div')
    sliderContainer.setAttribute 'class', '_pi_slider_question_container'
    containerNode.appendChild(sliderContainer)
    sliderContainer

  createHiddenSlider: (containerNode) ->
    sliderStartPosition = parseInt(@question.slider_start_position)

    hiddenSlider = document.createElement 'input'
    hiddenSlider.className = '_pi_hidden_slider'
    hiddenSlider.type = 'range'
    hiddenSlider.min = 0
    hiddenSlider.max = @question.possible_answers.length - 1
    hiddenSlider.step = 1
    hiddenSlider.defaultValue = sliderStartPosition
    hiddenSlider.ariaValueNow = sliderStartPosition
    hiddenSlider.ariaValueText = this.getPossibleAnswerByPosition(@question, sliderStartPosition).content
    containerNode.appendChild(hiddenSlider)

    hiddenSlider

  createSlider: (containerNode) ->
    slider = document.createElement('div')
    slider.className = "_pi_slider"
    slider.ariaHidden = true # The hidden slider takes care of screen readers
    containerNode.appendChild(slider)

    noUiSlider.create slider, {
      start: parseInt(@question.slider_start_position),
      range: {
        'min': 0,
        'max': @question.possible_answers.length - 1
      }
      connect: 'upper'
      step: 1,
      pips: {
        mode: 'count',
        values: @question.possible_answers.length
        # Making sub pips invisible https://refreshless.com/nouislider/pips/#section-steps
        # Usually main pips are Integer(e.g. 3) and sub pips are 2 decimal Float(e.g. 3.24), but there's a bug where a main pip holds too many decimals(e.g. 3.00000001) https://stackoverflow.com/q/44210566/12065544
        filter: (value, _type) -> if Number.isInteger(parseFloat(value.toFixed(2))) then 1 else -1
        format: {
          to: (position) -> survey = window.PulseInsightsObject.survey; content = survey.getPossibleAnswerByPosition(survey.question, position).content; window.PulseInsightsObject.survey.formatText(content)
        }
      }
      keyboardSupport: false # Pragmatically prevent the screen readers from reading out noUiSlider on desktop. We have a hidden range input element for the screen readers to read
    }
    slider

  createSliderSubmitButton: (containerNode) ->
    submitButtonContainer = document.createElement 'div'
    submitButtonContainer.setAttribute 'class', '_pi_slider_question_submit_button_container'
    containerNode.appendChild submitButtonContainer

    submitButton = document.createElement 'input'
    submitButton.setAttribute 'class', '_pi_slider_question_submit_button'
    submitButton.setAttribute 'type', 'submit'
    submitButton.setAttribute 'value', (@question.submit_label || "Submit")
    submitButtonContainer.appendChild submitButton

    submitButtonError = document.createElement 'div'
    submitButtonError.setAttribute 'class', '_pi_slider_question_submit_button_error'
    submitButtonError.setAttribute 'role', 'alert'
    submitButtonContainer.appendChild submitButtonError

    submitButton

  createAllAtOnceAlertForSlider: (containerNode) ->
    alertContainer = document.createElement 'div'
    alertContainer.setAttribute 'class', '_pi_all_at_once_slider_question_alert_container'
    containerNode.appendChild(alertContainer)

    emptyAnswerAlert = document.createElement 'div'
    emptyAnswerAlert.setAttribute 'class', '_pi_all_at_once_slider_question_empty_answer_alert'
    emptyAnswerAlert.setAttribute 'data-alert-text', @question.empty_error_text
    alertContainer.appendChild(emptyAnswerAlert)

  # TODO: Consolidate the styles for submit buttons, alerts and aria attributes of each question type in both rendering types
  sliderQuestionCSS: ->
    "
      input[type='range']._pi_hidden_slider {
        width: 50px;
        position: absolute;
        left: 40px;
      }

      ._pi_slider {
        margin: 0 35px 35px;
        font-size: 15px;
      }

      ._pi_slider_question_submit_button_container {
        padding-top: 30px;
      }

      input._pi_slider_question_submit_button {
        background-color: black;
        font-size: 15px;
        padding: 5px 20px;
        border: none;
        color: #eaf4fb;
        cursor: pointer;
      }

      input._pi_slider_question_submit_button:hover {
        background-color: #101010;
      }

      input._pi_slider_question_submit_button:disabled {
        opacity: 0.3;
      }

      input._pi_slider_question_submit_button:hover:disabled {
        background-color: black;
        opacity: 0.3;
      }

      ._pi_all_at_once_slider_question_alert_container {
        #{this.fontCSS()};
        font-size: 12px;
        color: #927a85;
        height: 17px;
      }

      ._pi_slider_question_submit_button_error {
        #{this.fontCSS()};
        text-align: center;
        font-size: 12px;
        color: #927a85;
        margin-top: 10px;
      }

      /*
       * Using the default CSS, pips would overlap with the one-at-a-time submit button in rendering(it'd still look fine visually)
       */
      .noUi-pips.noUi-pips-horizontal {
        height: 50px; /* original is 80px */
      }

      /*
       * Pip clicking feature
       * https://refreshless.com/nouislider/examples/#section-click-pips
       */
      .noUi-value {
        cursor: pointer;
      }

      /*
       * noUiSlider's default CSS
       * https://cdnjs.cloudflare.com/ajax/libs/noUiSlider/15.6.1/nouislider.min.css
       */
       .noUi-target,.noUi-target *{-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent;-webkit-user-select:none;-ms-touch-action:none;touch-action:none;-ms-user-select:none;-moz-user-select:none;user-select:none;-moz-box-sizing:border-box;box-sizing:border-box}.noUi-target{position:relative}.noUi-base,.noUi-connects{width:100%;height:100%;position:relative;z-index:1}.noUi-connects{overflow:hidden;z-index:0}.noUi-connect,.noUi-origin{will-change:transform;position:absolute;z-index:1;top:0;right:0;height:100%;width:100%;-ms-transform-origin:0 0;-webkit-transform-origin:0 0;-webkit-transform-style:preserve-3d;transform-origin:0 0;transform-style:flat}.noUi-txt-dir-rtl.noUi-horizontal .noUi-origin{left:0;right:auto}.noUi-vertical .noUi-origin{top:-100%;width:0}.noUi-horizontal .noUi-origin{height:0}.noUi-handle{-webkit-backface-visibility:hidden;backface-visibility:hidden;position:absolute}.noUi-touch-area{height:100%;width:100%}.noUi-state-tap .noUi-connect,.noUi-state-tap .noUi-origin{-webkit-transition:transform .3s;transition:transform .3s}.noUi-state-drag *{cursor:inherit!important}.noUi-horizontal{height:18px}.noUi-horizontal .noUi-handle{width:34px;height:28px;right:-17px;top:-6px}.noUi-vertical{width:18px}.noUi-vertical .noUi-handle{width:28px;height:34px;right:-6px;bottom:-17px}.noUi-txt-dir-rtl.noUi-horizontal .noUi-handle{left:-17px;right:auto}.noUi-target{background:#FAFAFA;border-radius:4px;border:1px solid #D3D3D3;box-shadow:inset 0 1px 1px #F0F0F0,0 3px 6px -5px #BBB}.noUi-connects{border-radius:3px}.noUi-connect{background:#3FB8AF}.noUi-draggable{cursor:ew-resize}.noUi-vertical .noUi-draggable{cursor:ns-resize}.noUi-handle{border:1px solid #D9D9D9;border-radius:3px;background:#FFF;cursor:default;box-shadow:inset 0 0 1px #FFF,inset 0 1px 7px #EBEBEB,0 3px 6px -3px #BBB}.noUi-active{box-shadow:inset 0 0 1px #FFF,inset 0 1px 7px #DDD,0 3px 6px -3px #BBB}.noUi-handle:after,.noUi-handle:before{content:\"\";display:block;position:absolute;height:14px;width:1px;background:#E8E7E6;left:14px;top:6px}.noUi-handle:after{left:17px}.noUi-vertical .noUi-handle:after,.noUi-vertical .noUi-handle:before{width:14px;height:1px;left:6px;top:14px}.noUi-vertical .noUi-handle:after{top:17px}[disabled] .noUi-connect{background:#B8B8B8}[disabled] .noUi-handle,[disabled].noUi-handle,[disabled].noUi-target{cursor:not-allowed}.noUi-pips,.noUi-pips *{-moz-box-sizing:border-box;box-sizing:border-box}.noUi-pips{position:absolute;color:#999}.noUi-value{position:absolute;white-space:nowrap;text-align:center}.noUi-value-sub{color:#ccc;font-size:10px}.noUi-marker{position:absolute;background:#CCC}.noUi-marker-sub{background:#AAA}.noUi-marker-large{background:#AAA}.noUi-pips-horizontal{padding:10px 0;height:80px;top:100%;left:0;width:100%}.noUi-value-horizontal{-webkit-transform:translate(-50%,50%);transform:translate(-50%,50%)}.noUi-rtl .noUi-value-horizontal{-webkit-transform:translate(50%,50%);transform:translate(50%,50%)}.noUi-marker-horizontal.noUi-marker{margin-left:-1px;width:2px;height:5px}.noUi-marker-horizontal.noUi-marker-sub{height:10px}.noUi-marker-horizontal.noUi-marker-large{height:15px}.noUi-pips-vertical{padding:0 10px;height:100%;top:0;left:100%}.noUi-value-vertical{-webkit-transform:translate(0,-50%);transform:translate(0,-50%);padding-left:25px}.noUi-rtl .noUi-value-vertical{-webkit-transform:translate(0,50%);transform:translate(0,50%)}.noUi-marker-vertical.noUi-marker{width:5px;height:2px;margin-top:-1px}.noUi-marker-vertical.noUi-marker-sub{width:10px}.noUi-marker-vertical.noUi-marker-large{width:15px}.noUi-tooltip{display:block;position:absolute;border:1px solid #D9D9D9;border-radius:3px;background:#fff;color:#000;padding:5px;text-align:center;white-space:nowrap}.noUi-horizontal .noUi-tooltip{-webkit-transform:translate(-50%,0);transform:translate(-50%,0);left:50%;bottom:120%}.noUi-vertical .noUi-tooltip{-webkit-transform:translate(0,-50%);transform:translate(0,-50%);top:50%;right:120%}.noUi-horizontal .noUi-origin>.noUi-tooltip{-webkit-transform:translate(50%,0);transform:translate(50%,0);left:auto;bottom:10px}.noUi-vertical .noUi-origin>.noUi-tooltip{-webkit-transform:translate(0,-18px);transform:translate(0,-18px);top:auto;right:28px}
    "
