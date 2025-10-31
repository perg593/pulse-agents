# Code specific to the handling of single choice questions

window.PulseInsightsInclude window.Survey,
  renderSingleChoiceQuestion: (possibleAnswersContainer, display_all_questions) ->
    self = this
    is_mobile = window.PulseInsightsObject.isMobile() && (@attributes["survey_type"]!=1 && @attributes["survey_type"]!=3)

    if @question.button_type == 0
      possibleAnswersContainer.setAttribute 'role', 'radiogroup'

    if @question.button_type == 2 # menu, select list
      possibleAnswerSelectList = document.createElement 'select'
      possibleAnswerSelectList.setAttribute 'class', '_pi_select'
      possibleAnswerSelectList.setAttribute 'aria-labelledby', "_pi_question_#{@question.id}"
      possibleAnswerSelectList.setAttribute 'aria-describedby', "_pi_question_#{@question.id}_empty_answer_alert"

      emptyOption = document.createElement 'option'
      emptyOption.setAttribute 'disabled', ''
      emptyOption.setAttribute 'selected', ''
      emptyOption.setAttribute 'value', ''
      emptyOption.innerHTML = this.escapeText(@question.single_choice_default_label)

      possibleAnswerSelectList.appendChild emptyOption

      for possibleAnswer in @question.possible_answers
        do (possibleAnswer) ->
          possibleAnswerOption = document.createElement 'option'
          possibleAnswerOption.setAttribute 'value', possibleAnswer.id
          possibleAnswerOption.setAttribute 'data-answer-id', possibleAnswer.id
          possibleAnswerOption.innerHTML = self.formatText(possibleAnswer.content)
          possibleAnswerOption.setAttribute 'data-possible-answer-locale-group-id', possibleAnswer.possible_answer_locale_group_id
          possibleAnswerSelectList.appendChild possibleAnswerOption

      possibleAnswersContainer.appendChild possibleAnswerSelectList

      # Attach onclick and keydown events
      if display_all_questions
        fillAnswerContainer = (answerContainer, possibleAnswerSelectList) ->
          answerContainer.setAttribute 'data-answer', possibleAnswerSelectList.value
          answerContainer.setAttribute 'data-answer-content', possibleAnswerSelectList.options[possibleAnswerSelectList.selectedIndex].text

        removeEmptyAnswerAlert = (answerContainer, possibleAnswerSelectList) ->
          emptyAnswerAlertLabel = answerContainer.querySelector('._pi_single_choice_empty_answer_alert')
          emptyAnswerAlertLabel.innerText = ''
          possibleAnswerSelectList.setAttribute 'aria-invalid', 'false'

        possibleAnswerSelectList.addEventListener 'keydown', (event) ->
          if event.key == 'Enter'
            event.preventDefault()
            window.PulseInsightsObject.survey.setControlTransitionFocus(true)
            answerContainer = this.parentNode
            fillAnswerContainer(answerContainer, this)

            survey = window.PulseInsightsObject.survey
            if survey.allAtOnceEmptyErrorEnabled() && !survey.isQuestionOptional(answerContainer)
              removeEmptyAnswerAlert(answerContainer, this)
            survey.checkSubmissionCompleteness answerContainer

        possibleAnswerSelectList.onchange = (event) ->
          answerContainer = this.parentNode
          fillAnswerContainer(answerContainer, this)

          window.PulseInsightsObject.survey.setControlTransitionFocus(window.PulseInsightsObject.survey.shouldControlFocus(event))

          survey = window.PulseInsightsObject.survey
          if survey.allAtOnceEmptyErrorEnabled() && !survey.isQuestionOptional(answerContainer)
            removeEmptyAnswerAlert(answerContainer, this)
          survey.checkSubmissionCompleteness answerContainer
      else
        possibleAnswerSelectList.addEventListener 'keydown', (event) ->
          if event.key == 'Enter'
            event.preventDefault()
            window.PulseInsightsObject.survey.answerClicked.call(possibleAnswerSelectList, event)

        possibleAnswerSelectList.onchange = window.PulseInsightsObject.survey.answerClicked
    else # standard or radio buttons
      questionId = @question.id
      for possibleAnswer in @question.possible_answers
        do (possibleAnswer) ->
          possibleAnswerElement = document.createElement 'li'

          # Create <a> link
          possibleAnswerElementLink = document.createElement 'a'
          possibleAnswerElementLink.setAttribute 'href', 'javascript:void(0)'

          role = if self.question.button_type == 0 then 'radio' else 'button'
          possibleAnswerElementLink.setAttribute 'role', role

          possibleAnswerElementLink.setAttribute 'data-answer-id', possibleAnswer.id
          possibleAnswerElementLink.setAttribute 'tabindex', '-1'
          possibleAnswerElementLink.setAttribute 'aria-describedby', "_pi_question_#{questionId}_empty_answer_alert"

          radioButtonOuterElement = document.createElement 'span'
          radioButtonOuterElement.setAttribute 'class', '_pi_radio_button_outer'

          radioButtonInnerElement = document.createElement 'span'
          radioButtonInnerElement.setAttribute 'class', '_pi_radio_button_inner'
          radioButtonOuterElement.appendChild radioButtonInnerElement

          possibleAnswerElementLink.appendChild radioButtonOuterElement

          if possibleAnswer.image_url
            possibleAnswerElementLink.setAttribute 'class', 'with-image'
            possibleAnswerElement.setAttribute 'class', 'with-image'
            possibleAnswerImage = document.createElement 'img'
            possibleAnswerImage.setAttribute 'src', possibleAnswer.image_url

            if window.PulseInsightsObject.deviceType() == 'mobile'
              image_height = possibleAnswer.image_height_mobile
              image_width = possibleAnswer.image_width_mobile
            else if window.PulseInsightsObject.deviceType() == 'tablet'
              image_height = possibleAnswer.image_height_tablet
              image_width = possibleAnswer.image_width_tablet
            else
              image_height = possibleAnswer.image_height
              image_width = possibleAnswer.image_width

            possibleAnswerImage.setAttribute 'height', image_height
            possibleAnswerImage.setAttribute 'width', image_width

            possibleAnswerImage.setAttribute 'alt', possibleAnswer.image_alt
            possibleAnswerElementLink.appendChild possibleAnswerImage

          unless self.question.image_type == '0'
            possibleAnswerLabelElement = document.createElement 'label'
            possibleAnswerLabelElement.setAttribute 'tabindex', '0'
            possibleAnswerLabelElement.setAttribute 'role', 'presentation'
            possibleAnswerLabelElement.setAttribute 'class', 'with-image' if possibleAnswer.image_url
            possibleAnswerLabelElement.innerHTML = self.formatText(possibleAnswer.content)
            possibleAnswerElementLink.appendChild possibleAnswerLabelElement

            if possibleAnswer.image_position == '0'       # top
              possibleAnswerElementLink.setAttribute 'class', 'with-img with-img-top'
            else if possibleAnswer.image_position == '1'  # bottom
              possibleAnswerElementLink.setAttribute 'class', 'with-img with-img-bottom'
            else if possibleAnswer.image_position == '2'  # right
              possibleAnswerElementLink.setAttribute 'class', 'with-img with-img-right'
            else if possibleAnswer.image_position == '3'  # left
              possibleAnswerElementLink.setAttribute 'class', 'with-img with-img-left'

          per_row = if is_mobile then self.question.answers_per_row_mobile else self.question.answers_per_row_desktop

          if self.question.button_type == 0 # radio button
            if per_row
              possibleAnswerElement.setAttribute 'style', "max-width: calc(#{100 / per_row}% - 20px);"

              if possibleAnswer.image_url
                possibleAnswerImage.setAttribute 'style', 'margin: 5px 25px;'
                radioButtonOuterElement.setAttribute 'style', 'top: calc(50% - 7px);'

          if self.question.button_type == 1 # standard button
            radioButtonOuterElement.setAttribute 'style', "display: none;"

            if self.question.desktop_width_type == 0 # fixed
              if per_row
                possibleAnswerElement.setAttribute 'style', "max-width: calc(#{100 / per_row}% - 20px);"
                possibleAnswerLabelElement.setAttribute 'style', "text-align: center;" unless self.question.image_type == '0'
            if self.question.desktop_width_type == 1 # variable
              possibleAnswerElementLink.setAttribute 'style', 'text-align: center;' if possibleAnswer.image_url
              possibleAnswerLabelElement.setAttribute 'style', "text-align: center; width: 100%; margin: 0;" unless self.question.image_type == '0'
              if self.question.answers_alignment_desktop == 0 && !self.displayFlexDisplay() # left
                possibleAnswerElement.setAttribute 'style', "width: auto; max-width: none; float: left; display: block;"
              if self.question.answers_alignment_desktop == 1 && !self.displayFlexDisplay() # center
                possibleAnswerElement.setAttribute 'style', "width: auto; max-width: none; float: none; display: inline-block;"

          # Attach onclick and keydown events
          if display_all_questions
            removeEmptyAnswerAlert = (answerContainer) ->
              emptyAnswerAlertLabel = answerContainer.querySelector('._pi_single_choice_empty_answer_alert')
              firstPossibleAnswer = answerContainer.querySelector('a')
              emptyAnswerAlertLabel.innerText = ''
              firstPossibleAnswer.setAttribute 'aria-invalid', 'false'

            possibleAnswerElementLink.addEventListener 'keydown', (event) ->
              if event.key == 'Enter' || event.code == 'Space'
                event.preventDefault()
                window.PulseInsightsObject.survey.setControlTransitionFocus(true)

                for other_li in this.parentElement.parentElement.querySelectorAll('li')
                  other_li.setAttribute 'class', ''

                this.parentElement.setAttribute 'class', "selected"

                answerContainer = this.parentNode.parentNode
                answerContainer.setAttribute 'data-answer', this.getAttribute('data-answer-id')

                survey = window.PulseInsightsObject.survey
                if survey.allAtOnceEmptyErrorEnabled() && !survey.isQuestionOptional(answerContainer)
                  removeEmptyAnswerAlert(answerContainer)
                survey.checkSubmissionCompleteness answerContainer

            possibleAnswerElementLink.onclick = (event) ->
              window.PulseInsightsObject.survey.setControlTransitionFocus(window.PulseInsightsObject.survey.shouldControlFocus(event))

              event.preventDefault()

              for other_li in this.parentElement.parentElement.querySelectorAll('li')
                other_li.setAttribute 'class', ''

              this.parentElement.setAttribute 'class', "selected"

              answerContainer = this.parentNode.parentNode
              answerContainer.setAttribute 'data-answer', this.getAttribute('data-answer-id')
              answerContainer.setAttribute 'data-answer-content', this.text

              survey = window.PulseInsightsObject.survey
              if survey.allAtOnceEmptyErrorEnabled() && !survey.isQuestionOptional(answerContainer)
                removeEmptyAnswerAlert(answerContainer)
              survey.checkSubmissionCompleteness answerContainer
          else
            possibleAnswerElementLink.addEventListener 'keydown', (event) ->
              if event.key == 'Enter' || event.code == 'Space'
                event.preventDefault()
                window.PulseInsightsObject.survey.answerClicked.call(possibleAnswerElementLink, event)

            possibleAnswerElementLink.onclick = window.PulseInsightsObject.survey.answerClicked

          possibleAnswerElementLink.setAttribute 'data-possible-answer-locale-group-id', possibleAnswer.possible_answer_locale_group_id

          # Add link to <li> element
          possibleAnswerElement.appendChild possibleAnswerElementLink

          # Add <li> element to <ul> list
          possibleAnswersContainer.appendChild possibleAnswerElement

    if self.isAllAtOnce() && self.allAtOnceEmptyErrorEnabled() && !self.isQuestionOptional(possibleAnswersContainer)
      # Create label container
      labelContainer = document.createElement 'div'
      labelContainer.setAttribute 'class', '_pi_single_choice_question_label_container'
      possibleAnswersContainer.appendChild labelContainer

      # Create empty answer alert label
      emptyAnswerAlertLabel = document.createElement 'div'
      emptyAnswerAlertLabel.setAttribute 'id', "_pi_question_#{@question.id}_empty_answer_alert"
      emptyAnswerAlertLabel.setAttribute 'class', '_pi_single_choice_empty_answer_alert'
      emptyAnswerAlertLabel.setAttribute 'data-alert-text', @question.empty_error_text
      labelContainer.appendChild emptyAnswerAlertLabel

  addSingleChoiceEmptyAnswerAlert: (answerContainer) ->
    emptyAnswerAlertLabel = answerContainer.querySelector('._pi_single_choice_empty_answer_alert')
    emptyAnswerAlertLabel.innerText = emptyAnswerAlertLabel.getAttribute('data-alert-text')

  setSingleChoiceAriaInvalid: (answerContainer) ->
    # The first interactive element is the element to focus on for accessibility when submit fails
    firstInteractiveElement = answerContainer.querySelector('select') || answerContainer.querySelector('a')
    firstInteractiveElement.setAttribute 'aria-invalid', 'true'

  singleChoiceQuestionCSS: ->
    "
      ._pi_single_choice_question_label_container {
        clear: both;
        margin: 0px 18px 0px;
      }

      ._pi_single_choice_empty_answer_alert {
        #{this.fontCSS()};
        font-size: 12px;
        color: #927a85;
      }
    "
