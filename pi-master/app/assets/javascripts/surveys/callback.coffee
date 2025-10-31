# Client-side integration
#
# Usage(The ones that involve clicking offer an event object as the 2nd argument):
#   pi('onclose', function(survey, event) {});
#   pi('oncomplete', function(survey) {});
#   pi('onanswer', function(survey, event) {});
#   pi('onimpression', function(survey) {});
#   pi('onview', function(survey) {});
#   pi('onclick', function(survey, event) {});

window.PulseInsightsInclude window.PulseInsights,
  onclose: (callbackFunction) ->
    @log "Onclose Callback function enabled."
    @OncloseCallbackFunction = callbackFunction

  oncomplete: (callbackFunction) ->
    @log "Oncomplete Callback function enabled."
    @OncompleteCallbackFunction = callbackFunction

  onanswer: (callbackFunction) ->
    @log "Onanswer Callback function enabled."
    @OnanswerCallbackFunction = callbackFunction

  onimpression: (callbackFunction) ->
    @log "Onimpression Callback function enabled."
    @OnimpressionCallbackFunction = callbackFunction

  onview: (callbackFunction) ->
    @log "Onview Callback function enabled."
    @OnviewCallbackFunction = callbackFunction

  onclick: (callbackFunction) ->
    @log "Onclick Callback function enabled."
    @OnclickCallbackFunction = callbackFunction

  triggerOnCloseCallback: (event) ->
    @log "Try to trigger onclose callbacks."

    if @OncloseCallbackFunction?
      @log "Triggering custom onclose callback"
      @OncloseCallbackFunction.apply this, [this.survey, event]

    if !this.survey.attributes.onclose_callback_code? || this.survey.attributes.onclose_callback_code.length == 0
      @log "No onclose callbacks defined in console"
      return "none defined"

    if this.survey.onclose_callback_executed?
      @log "onclose callback already executed"
      return

    @log "Triggering on close callback set in console"
    try
      survey = this.survey
      eval this.survey.attributes.onclose_callback_code
    catch error
      @log "Error while executing on close callback: "+error
    @survey.onclose_callback_executed = true

  triggerOnCompleteCallback: ->
    @log "Try to trigger on complete callbacks."

    if @OncompleteCallbackFunction? && this.survey.answers? && this.survey.answers.length > 0
      @log "Triggering custom on complete callback"
      @OncompleteCallbackFunction.apply this, [this.survey]

    if !this.survey.attributes.oncomplete_callback_code? || this.survey.attributes.oncomplete_callback_code.length == 0 || this.survey.oncomplete_callback_executed?
      @log "No oncomplete callbacks defined in console"
      return

    if !this.survey.answers? || this.survey.answers.length == 0
      @log "No oncomplete callbacks fired when closing the survey without answer"
      return

    @log "Triggering on complete callback set in console"
    try
      survey = this.survey
      eval this.survey.attributes.oncomplete_callback_code
    catch error
      @log "Error while executing on complete callback: "+error
    @survey.oncomplete_callback_executed = true

  triggerOnAnswerCallback: (event) ->
    @log "Try to trigger on answer callbacks."

    if @OnanswerCallbackFunction?
      @log "Triggering custom on answer callback"
      @OnanswerCallbackFunction.apply this, [this.survey, event]

    if ! this.survey.attributes.onanswer_callback_code? || this.survey.attributes.onanswer_callback_code.length == 0
      @log "No answer callbacks defined in console"
      return

    @log "Triggering on answer callback set in console"
    try
      survey = this.survey
      question = this.survey.question

      if this.survey.question.question_type == 'free_text_question'
        answer = { id: null, content: this.survey.textInput.value, next_question_id: this.survey.question.next_question_id }

      if this.survey.question.question_type == 'multiple_choices_question'
        answer = { id: [], content: [], next_question_id: [] }

        for answerId in survey.multipleChoiceAnswerIds(question.id)
          possibleAnswer = question.possible_answers.find((possibleAnswer) => possibleAnswer.id == parseInt(answerId))
          answer.content.push(possibleAnswer.content)
          answer.id.push(possibleAnswer.id)
          answer.next_question_id.push(possibleAnswer.next_question_id)

      if this.survey.question.question_type == 'single_choice_question'
        for possible_answer in this.survey.question.possible_answers
          answer = possible_answer if possible_answer.id == parseInt(this.survey.answerId)

      eval this.survey.attributes.onanswer_callback_code
    catch error
      @log "Error while executing on answer callback: "+error

  triggerOnImpressionCallback: ->
    @log "Try to trigger onimpression callback (Custom Data Snippet)"

    if @OnimpressionCallbackFunction?
      @log "Triggering custom onimpression callback"
      @OnimpressionCallbackFunction.apply this, [this.survey]

    if !this.survey.attributes.custom_data_snippet? || this.survey.attributes.custom_data_snippet.length == 0
      @log "No onimpression callback set in console"
      return

    if this.survey.onimpression_callback_executed?
      @log "Onimpression callback already executed"
      return

    @log "Triggering onimpression callback set in console"
    try
      eval this.survey.attributes.custom_data_snippet
    catch error
      @log "Error while executing onimpression callback (custom data snippet): "+error

    @survey.onimpression_callback_executed = true

  triggerOnViewCallback: ->
    @log "Try to trigger onview callback"

    if @OnviewCallbackFunction?
      @log "Triggering custom onview callback"
      @OnviewCallbackFunction.apply this, [this.survey]

    if !this.survey.attributes.onview_callback_code? || this.survey.attributes.onview_callback_code.length == 0
      @log "No onview callback set in console"
      return

    if this.survey.onview_callback_executed?
      @log "Onview callback already executed"
      return

    @log "Triggering onview callback set in console"
    try
      eval this.survey.attributes.onview_callback_code
    catch error
      @log "Error while executing onview callback: "+error

    @survey.onview_callback_executed = true

  triggerOnClickCallback: (event) ->
    @log "Try to trigger onclick callback"

    if @OnclickCallbackFunction?
      @log "Triggering custom onclick callback"
      @OnclickCallbackFunction.apply this, [this.survey, event]

    if !this.survey.attributes.onclick_callback_code? || this.survey.attributes.onclick_callback_code.length == 0
      @log "No onclick callback set in console"
      return

    @log "Triggering onclick callback set in console"
    try
      eval this.survey.attributes.onclick_callback_code
    catch error
      @log "Error while executing onclick callback: "+error
