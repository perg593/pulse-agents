class window.Survey
  constructor: (_attributes) ->
    @attributes = _attributes
    @started = false
    @controlTransitionFocus = false
    if @attributes.questions
      @questions = @attributes.questions

  id: ->
    @attributes['id']

  widgetParent: ->
    document.getElementsByTagName('body')[0]

  widgetPositioning: ->
    ""

  fontCSS: ->
    " font-family: Helvetica, Arial, sans-serif;
      font-size: 16px;
      font-weight: normal;
    "

  additionalTextCss: ->
    "
      ._pi_header {
         color: white;
         margin: 0;
         width: 100%;
      }

      ._pi_header_before {
         font-size: 22px;
         font-weight: 100;
         padding: 10px 0 10px;
         text-align: left;
         width: 100%;
      }

      .all-at-once ._pi_header_before {
        font-size: 28px;
      }

      ._pi_header_after {
        font-size: 14px;
        font-weight: 100;
        padding: 5px;
      }

      .all-at-once ._pi_header_after {
        background-color: #eeeeee;
        font-size: 13px;
      }

      ._pi_scale_container {
        color: white;
        width:98%;
        display: flex;
        margin: auto;
        padding: 5px 0;
      }

      ._pi_scale_container[data-scale-items=\"1\"]  ._pi_scale { max-width: calc(100% / 1); }
      ._pi_scale_container[data-scale-items=\"2\"]  ._pi_scale { max-width: calc(100% / 2); }
      ._pi_scale_container[data-scale-items=\"3\"]  ._pi_scale { max-width: calc(100% / 3); }
      ._pi_scale_container[data-scale-items=\"4\"]  ._pi_scale { max-width: calc(100% / 4); }
      ._pi_scale_container[data-scale-items=\"5\"]  ._pi_scale { max-width: calc(100% / 5); }
      ._pi_scale_container[data-scale-items=\"6\"]  ._pi_scale { max-width: calc(100% / 6); }
      ._pi_scale_container[data-scale-items=\"7\"]  ._pi_scale { max-width: calc(100% / 7); }
      ._pi_scale_container[data-scale-items=\"8\"]  ._pi_scale { max-width: calc(100% / 8); }
      ._pi_scale_container[data-scale-items=\"9\"]  ._pi_scale { max-width: calc(100% / 9); }
      ._pi_scale_container[data-scale-items=\"10\"] ._pi_scale { max-width: calc(100% / 10); }
      ._pi_scale_container[data-scale-items=\"11\"] ._pi_scale { max-width: calc(100% / 11); }

      ._pi_scale {
         flex: 1 0 auto;
      }

      ._pi_scale_container_after {
        margin-bottom: 20px;
      }

      ._pi_scale_container_before {
        margin-top: 20px;
      }

      ._pi_scale_first  { text-align: left;     margin-right: 2px; }
      ._pi_scale_middle { text-align: center;   margin: 0 2px 0}
      ._pi_scale_last   { text-align: right;    margin-left: 2px}
    "

  flexCssStyle: ->
    " ul._pi_answers_container {
        list-style: none !important;
        display: -webkit-box !important;
        display: -ms-flexbox !important;
        display: flex !important;
        -webkit-box-orient: horizontal !important;
        -webkit-box-direction: normal !important;
        -ms-flex-direction: row !important;
        flex-direction: row !important;
        -ms-flex-wrap: wrap !important;
        flex-wrap: wrap !important;
        -webkit-box-align: stretch !important;
        -ms-flex-align: stretch !important;
        align-items: stretch !important;
        -ms-flex-line-pack: stretch !important;
        align-content: stretch !important;
      }

      ul._pi_answers_container li,
      ul._pi_answers_container li a,
      ul._pi_answers_container li a label,
      ul._pi_answers_container li label._pi-control-checkbox {
        cursor: pointer !important;
        -webkit-box-sizing: border-box;
        box-sizing: border-box;
      }

      ul._pi_answers_container li {
        text-align: inherit !important;
        width: auto !important;
        height: auto !important;
        overflow: hidden !important;
        max-width: none !important;
        float: none !important;
        padding: 0 !important;
        margin: 5px 0 !important;
        display: -webkit-box;
        display: -ms-flexbox;
        display: flex;
        -webkit-box-orient: horizontal;
        -webkit-box-direction: normal;
        -ms-flex-direction: row;
        flex-direction: row;
        -ms-flex-wrap: wrap;
        flex-wrap: wrap;
        -webkit-box-pack: center;
        -ms-flex-pack: center;
        justify-content: center;
        -webkit-box-align: stretch;
        -ms-flex-align: stretch;
        align-items: stretch;
        -ms-flex-line-pack: stretch;
        align-content: stretch;
      }

      /* ------------------------------ SINGLE CHOICE ------------------------------ */
      ul._pi_answers_container li a {
        padding: 0 20px;
        height: auto;
        -webkit-box-flex: 0;
        -ms-flex-positive: 0;
        flex-grow: 0;
        -ms-flex-negative: 0;
        flex-shrink: 0;
        -ms-flex-preferred-size: 100%;
        flex-basis: 100%;
        position: static;
        display: -webkit-box;
        display: -ms-flexbox;
        display: flex;
        -webkit-box-orient: horizontal;
        -webkit-box-direction: normal;
        -ms-flex-direction: row;
        flex-direction: row;
        -ms-flex-wrap: nowrap;
        flex-wrap: nowrap;
        -webkit-box-pack: start;
        -ms-flex-pack: start;
        justify-content: flex-start;
        -webkit-box-align: center;
        -ms-flex-align: center;
        align-items: center;
        -ms-flex-line-pack: center;
        align-content: center;
        min-width: 100% !important;
      }

      /* ===================== ANSWERS CONTAINER =============================== */
      /* LEGACY SCENARIOS */
      div[data-answer-widths='fixed']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answer-widths='fixed'] {
         justify-content: flex-start;
      }

      div[data-answer-widths='variable-center']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answer-widths='variable-center'] {
         justify-content: center;
      }

      div[data-answer-widths='variable-left']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answer-widths='variable-left'] {
         justify-content: flex-start;
      }


      /* LAYOUT SCENARIOS */
      div[data-answers-layout='fixed']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answers-layout='fixed'] {
         justify-content: flex-start;
      }

      div[data-answers-layout='variable']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answers-layout='variable'] {
         justify-content: center;
      }


      /* FLEX ALIGNMENT SCENARIOS */
      div[data-answers-alignment='center']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answers-alignment='center'] {
         justify-content: center;
      }

      div[data-answers-alignment='left']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answers-alignment='left'] {
         justify-content: flex-start;
      }

      div[data-answers-alignment='right']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answers-alignment='right'] {
         justify-content: flex-end;
      }

      div[data-answers-alignment='space-between']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answers-alignment='space-between'] {
         justify-content: space-between;
      }

      div[data-answers-alignment='space-around']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answers-alignment='space-around'] {
         justify-content: space-around;
      }

      div[data-answers-alignment='space-evenly']:not([data-survey-display='all-at-once']) ul._pi_answers_container,
      ul[data-answers-alignment='space-evenly'] {
         justify-content: space-evenly;
      }



      /* ===================== LI WIDTHS AND MARGINS ========================== */

      /* LI MARGINS */
      div[data-answers-alignment='center']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      div[data-answers-alignment='left']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      div[data-answers-alignment='right']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      div[data-answers-alignment='space-around']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      div[data-answers-alignment='space-between']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      div[data-answers-alignment='space-evenly']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-alignment='center'] li,
      ul[data-answers-alignment='left'] li,
      ul[data-answers-alignment='right'] li,
      ul[data-answers-alignment='space-around'] li,
      ul[data-answers-alignment='space-between'] li,
      ul[data-answers-alignment='space-evenly'] li {
         box-sizing: border-box !important;
         margin: 5px 1% !important;
      }



      /* VARIABLE WIDTHS */
      div[data-answers-layout='variable']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='variable'] li {
         flex-grow: 0;
         flex-shrink: 0;
         flex-basis: auto;
      }


      /* FIXED: DEFAULT: 3 PER ROW */
      div[data-answers-layout='fixed']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'] li {
        flex: 0 0      calc((100% / 3) - 2%) !important;
        max-width:     calc((100% / 3) - 2%) !important;
      }


      /* FIXED: X ITEMS PER ROW */
      div[data-answers-layout='fixed'][data-answers-per-row='1']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='1'] li {
         margin: 5px 7% !important;
         flex: 0 0 86% !important;  /* SPECIAL CASE FOR ONE ITEM PER ROW */
         max-width: 86% !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='2']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='2'] li {
        flex: 0 0      calc((100% / 2) - 2%) !important;
        max-width:     calc((100% / 2) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='3']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='3'] li {
        flex: 0 0      calc((100% / 3) - 2%) !important;
        max-width:     calc((100% / 3) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='4']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='4'] li {
        flex: 0 0      calc((100% / 4) - 2%) !important;
        max-width:     calc((100% / 4) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='5']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='5'] li {
        flex: 0 0      calc((100% / 5) - 2%) !important;
        max-width:     calc((100% / 5) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='6']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='6'] li {
        flex: 0 0      calc((100% / 6) - 2%) !important;
        max-width:     calc((100% / 6) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='7']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='7'] li {
        flex: 0 0      calc((100% / 7) - 2%) !important;
        max-width:     calc((100% / 7) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='8']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='8'] li {
        flex: 0 0      calc((100% / 8) - 2%) !important;
        max-width:     calc((100% / 8) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='9']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='9'] li {
        flex: 0 0      calc((100% / 9) - 2%) !important;
        max-width:     calc((100% / 9) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='10']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='10'] li {
        flex: 0 0      calc((100% / 10) - 2%) !important;
        max-width:     calc((100% / 10) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='11']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='11'] li {
        flex: 0 1      calc((100% / 11) - 2%) !important;
        max-width:     calc((100% / 11) - 2%) !important;
      }

      div[data-answers-layout='fixed'][data-answers-per-row='12']:not([data-survey-display='all-at-once']) ul._pi_answers_container li,
      ul[data-answers-layout='fixed'][data-answers-per-row='12'] li {
        flex: 0 0      calc((100% / 12) - 2%) !important;
        max-width:     calc((100% / 12) - 2%) !important;
      }
    "
  cssStyle: ->
    "
    #_pi_surveyWidgetContainer {
      z-index: 1031;
    }

    #_pi_surveyWidgetCustom {
      #{this.fontCSS()}
      position: fixed;
      top: 0;
      left: 0;
      padding: 0;
      margin: 0;
      width: 100%;
      height: 100%;
      z-index: 1032;
      -moz-transition: 0.2s;
      -ms-transition: 0.2s;
      -o-transition: 0.2s;
      -webkit-transition: 0.2s;
      transition: 0.2s;

      font-size: 16px;

      z-index: 18000;

      overflow: hidden;
    }

    #_pi_surveyWidget {
      #{this.fontCSS()}
      position: fixed;
      max-height: 0px;
      height: auto;
      width:#{this.width()};
      #{this.widgetPositioning();};
      background-color: #{this.backgroundColor()};
      text-align: center;
      z-index: 1032;

      -moz-transition: 0.2s;
      -ms-transition: 0.2s;
      -o-transition: 0.2s;
      -webkit-transition: 0.2s;
      transition: 0.2s;

      font-size: 16px;

      z-index: 18000;

      overflow: hidden;
    }

    ._pi_closeCustomButton {
      #{this.fontCSS()}
      position: absolute;
      top: 6px;
      right: 10px;
      color: #000;
      cursor: pointer;
    }

    ._pi_closeButton {
      #{this.fontCSS()}
      position: absolute;
      top: 6px;
      right: 10px;
      color: #fff;
      cursor: pointer;
    }

    ._pi_invitationTextContainer {
      #{this.fontCSS()}
      color: #{this.textColor()};
      cursor: pointer;
    }

    ._pi_background_image {
      max-width: 100%;
    }

    ._pi_startButton {
      #{this.fontCSS()}
      padding: 8px 12px;
      background-color: black;
      color: white;
    }

    ._pi_startButton:hover {
      text-decoration: none;
    }

    ._pi_loadingSurvey, ._pi_thankYouSurvey {
      #{this.fontCSS()}
      color: #{this.textColor()};
    }

    ._pi_pollContainer {
      #{this.fontCSS()}
      color: #{this.textColor()};
      padding: 30px 0px 30px 0px;
      text-align: left;
    }

    ._pi_pollChoice {
      margin-top: 2px;
      margin-bottom: 2px;
      margin-left: 7px;
      overflow: hidden;
      position: relative;
      display: block;
      cursor: inherit;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    ._pi_pollChart {
      background-color: rgba(255,255,255,0.15);
      position: absolute;
      top: 0;
      left: 0;
      width: 0;
      height: 100%;
      transition: all .3s cubic-bezier(0.5,1.2,.5,1.2);
      opacity: 1;
    }

    ._pi_pollProgress {
      display: inline-block;
      max-width: 100%;
      margin-bottom: 30px;
      margin-left: 7px;
      font-size: 12px;
      overflow: hidden;
    }

    ._pi_pollProgressPercentage {
       display: inline-block;
    }

    ._pi_pollProgressCount {
       display: inline-block;
       margin-left: 5px;
    }

    ._pi_pollText {
      position: relative;
      display: inline-block;
    }

    ._pi_pollText span {
      vertical-align: middle;
    }

    ._pi_pollName {
      font-size: 14px;
      margin-left: 7px;
    }

    ._pi_question {
      #{this.fontCSS()}
      color: #{this.textColor()};
      text-align: left;
      padding: 0px 20px;
      margin-top: 20px;
    }

    ._pi_question_custom_content_question_fullscreen {
      color: black;
    }

    ._pi_answers_container {
      margin-top: 10px;
    }

    ul._pi_answers_container,
    div._pi_answers_container {
      list-style-type: none;
      padding: 0px 0px 20px 0px;
      margin: 10px 0px;
      width: 100%;
      overflow: hidden;
    }

    ul._pi_answers_container li {
      background-color: rgba(255, 255, 255, 0.05);
      text-align: left;
      margin: 15px 0px;
      padding: 0px 20px;
      width: 100%;
      overflow: hidden;
      max-width: 460px;
      float: left;
      -webkit-box-sizing: border-box;
      -moz-box-sizing: border-box;
      box-sizing: border-box;
    }

    ul._pi_answers_container li:hover {
      background-color: rgba(255, 255, 255, 0.1);
    }

    ul._pi_answers_container li a {
      position: relative;
      display: block;
      color: #{this.answerTextColor()};
      #{this.fontCSS()}
      margin: 0px;
      padding: 0px 20px 0px 0px;
      text-decoration: none;
    }

    ul._pi_answers_container li a img {
      margin: 5px 0;
    }


    ul._pi_answers_container li a label.with-image {
      float: none!important;
      margin-left: 5px;
      width: auto;
    }

    ul._pi_answers_container li a label {
      color: #{this.answerTextColor()};
      #{this.fontCSS()}
      width: 100%;
      width: -moz-calc(100% - 35px);
      width: -webkit-calc(100% - 35px);
      width: calc(100% - 35px);
      float: left;
      cursor: pointer;
      margin: 0px 0px 0px 25px;
      padding: 5px 0px 5px 0px;
    }

    ul._pi_answers_container li a span._pi_radio_button_outer {
      position: absolute;
      top: 10px;
      left: 0px;
      display: inline-block;
      float: left;
      border: 1px solid rgba(255,255,255,0.5);
      border-radius: 50%;
      width: 14px;
      height: 14px;
    }

    ul._pi_answers_container li a span._pi_radio_button_inner,
    ul._pi_answers_container li a span._pi_checkbox_inner {
      position: absolute;
      top: 2px;
      left: 2px;
      width: 8px;
      height: 8px;
    }

    ul._pi_answers_container li:hover a span._pi_radio_button_inner,
    ul._pi_answers_container li.selected a span._pi_radio_button_inner {
      background-color: rgba(255,255,255,0.5);
      border: 1px solid transparent;
      border-radius: 50%;
    }

    a._pi_branding {
      #{this.fontCSS()}
      color: white;
      font-size: 10px;
      position: absolute;
      bottom: 8px;
      left: 8px;
    }

    a._pi_branding:hover {
      #{this.fontCSS()}
      color: white;
      font-size: 10px;
      text-decoration: none;
    }

    div._pi_all_questions_submit_button_container {
      margin-bottom: 25px;
      clear: both;
    }

    input._pi_all_questions_submit_button {
      background-color: black;
      font-size: 15px;
      padding: 5px 20px;
      border: none;
      color: #eaf4fb;
      cursor: pointer;
    }

    input._pi_all_questions_submit_button:hover {
      background-color: #101010;
    }

    input._pi_all_questions_submit_button:disabled {
      opacity: 0.3;
    }

    input._pi_all_questions_submit_button:hover:disabled {
      background-color: black;
      opacity: 0.3;
    }

    ._pi_all_at_once_submit_error {
      #{this.fontCSS()};
      text-align: center;
      font-size: 12px;
      color: #927a85;
      margin-top: 10px;
    }

    ._pi_screen_reader_only {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      border: 0;
    }

    #{@additionalTextCss()}
    #{@freeTextQuestionCSS()}
    #{@multipleChoicesQuestionCSS()}
    #{@singleChoiceQuestionCSS()}
    #{@sliderQuestionCSS()}
    "

  borderColor: ->
    "rgba(174, 174, 174, 0.6);"


  mobileCssStyle: ->
    "
    #_pi_surveyWidgetContainer.mobile-enabled {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      text-align: center;
      background-color: rgba(0, 0, 0, 0.5);
    }

    #_pi_surveyWidgetContainer.mobile-enabled #_pi_surveyWidget {
      width: 90%;
      position: relative;
      top: auto;
      left: auto;
      right: auto;
      bottom: auto;
      margin-top: 10%;
      margin-left: auto;
      margin-right: auto;
      border: 3px solid #{this.borderColor()};
      border-radius: 5px;
    }

    #_pi_surveyWidgetContainer.mobile-enabled ._pi_closeButton {
      background-color: rgba(255, 255, 255, 0.1);
      width: 40px;
      height: 40px;
      font-size: 20px;
      line-height: 40px;
    }

    #_pi_surveyWidgetContainer.mobile-enabled ._pi_widgetContentContainer {
      margin-top: 10px;
    }

    #{@additionalTextCss()}
    #{@freeTextQuestionCSS()}
    #{@multipleChoicesQuestionCSS()}
    #{@singleChoiceQuestionCSS()}
    #{@sliderQuestionCSS()}
  "

  position: ->
    _position =
      top: (if @attributes['top_position']=="" then null else @attributes['top_position'])
      bottom: (if @attributes['bottom_position']=="" then null else @attributes['bottom_position'])
      left: (if @attributes['left_position']=="" then null else @attributes['left_position'])
      right: (if @attributes['right_position']=="" then null else @attributes['right_position'])
    _position

  width: ->
    if @attributes["width"] == 0
      "300px"
    else
      @attributes["width"]+"px"

  height: ->
    "auto"

  backgroundColor: ->
    @attributes["background_color"] || "#181818"

  textColor: ->
    @attributes["text_color"] || "white"

  answerTextColor: ->
    @attributes["answer_text_color"] || "white"

  invitationText: ->
    @attributes["invitation"] || ""

  invitationButtonText: ->
    @attributes["invitation_button"] || ""

  invitationButtonDisabled: ->
    @attributes["invitation_button_disabled"] || "f"

  thankYouText: ->
    @attributes["thank_you"] || "Thank you!"

  allAtOnceEmptyErrorEnabled: ->
    @attributes["all_at_once_empty_error_enabled"] == 't'

  isAllAtOnce: ->
    @attributes["display_all_questions"] == 't'

  log: (message) ->
    window.PulseInsightsObject.log(message)

  loadQuestions: ->
    if @questions?
      this.questionsLoaded(@questions)
    else
      window.PulseInsightsObject.jsonpGet "/surveys/#{this.id()}/questions", { identifier: window.PulseInsightsObject.identifier }, this.questionsLoaded

  questionsLoaded: (data) ->
    survey = window.PulseInsightsObject.survey
    survey.questions = data
    if survey.attributes.randomize_question_order == 't'
      survey.randomizeQuestions(survey.questions)
    survey.question = survey.questions[0]

    if survey.attributes.randomize_question_order == 'f'
      for q in survey.questions
        do (q) ->
          if q.position < survey.question.position
            survey.question = q

    if survey.attributes.display_all_questions == 't'
      survey.renderAllQuestions()
    else
      survey.renderCurrentQuestion()

  randomizeQuestions: (questions) ->
    i = questions.length - 1
    while i > 0
      j = Math.floor(Math.random() * (i + 1))
      if questions[i].question_type == "custom_content_question" # skip custom content questions
        i--
        continue
      temp = questions[j] # swap elements
      questions[j] = questions[i]
      questions[i] = temp
      i--
    i = questions.length - 1
    while i > 0 # set next question ids appropriately
      j = i - 1
      if questions[j].next_question_id != null
        questions[j].next_question_id = questions[i].id
      if questions[j].possible_answers != undefined
        for possible_answer in questions[j].possible_answers
          do (possible_answer) ->
            possible_answer.next_question_id = questions[i].id
      i--

  isQuestionOptional: (answerContainer) ->
    answerContainer.getAttribute('data-question-optional') == 't'

  getQuestionById: (questionId) ->
    this.questions.find((question) -> question.id == parseInt(questionId))

  getPossibleAnswerByPosition: (question, position) ->
    question.possible_answers.find((possibleAnswer) -> possibleAnswer.position == parseInt(position))

  #
  # Events
  #

  getAnswerElement: (target) ->
    if target.tagName == "A"
      return target
    parent = target
    parent = parent.parentNode while (parent && parent.tagName != "A")
    parent

  nextQuestionButtonClicked: (event) ->
    window.PulseInsightsObject.survey.next_question = this.getAttribute('data-question-id')
    if window.PulseInsightsObject.submission?
      submissionUdid = window.PulseInsightsObject.submission.udid
    else
      submissionUdid = null

    questionId = window.PulseInsightsObject.survey.question.id
    params =
      identifier: window.PulseInsightsObject.identifier
      question_id: questionId
      next_question_id: this.getAttribute('data-question-id')

    # If there's custom data, send it along with the answer because
    #  it may have changed since the call to get the survey.
    if window.PulseInsightsObject.customData?
      params['custom_data'] = window.PulseInsightsObject.stringify(window.PulseInsightsObject.customData)

    if window.PulseInsightsObject.client_key
      params['client_key'] = window.PulseInsightsObject.getClientKey()

    if window.PulseInsightsObject.previewMode
      window.PulseInsightsObject.survey.customAnswersSubmitted()
      return false

    window.PulseInsightsObject.jsonpGet "/submissions/#{submissionUdid}/answer", params, window.PulseInsightsObject.survey.customAnswersSubmitted
    false

  allQuestionsSubmitClicked: (event) ->
    event.preventDefault()
    event.stopPropagation()

    survey = window.PulseInsightsObject.survey

    if survey.allAtOnceEmptyErrorEnabled()
      survey.checkEmptyAnswers()
      survey.focusOnFirstInvalidAnswer()

    if survey.allSubmitButton.getAttribute('data-submit-error')
      survey.allSubmitButtonError.innerHTML = survey.escapeText(survey.attributes.all_at_once_error_text)
      return

    survey.answers = []

    for answerContainer in document.querySelectorAll('._pi_answers_container')
      survey.storeAnswer(answerContainer) unless survey.answerIsInvalid(answerContainer)

    params =
      identifier: window.PulseInsightsObject.identifier
      answers: JSON.stringify(survey.answers)

    if window.PulseInsightsObject.customData?
      params['custom_data'] = window.PulseInsightsObject.stringify(window.PulseInsightsObject.customData)

    if window.PulseInsightsObject.client_key
      params['client_key'] = window.PulseInsightsObject.getClientKey()

    if window.PulseInsightsObject.submission?
      submissionUdid = window.PulseInsightsObject.submission.udid
    else
      submissionUdid = null

    if window.PulseInsightsObject.previewMode
      params['preview_mode'] = true
    else
      window.PulseInsightsObject.triggerOnAnswerCallback(event)

    if PulseInsightsObject.pdfResultsDesignated
      PulseInsightsObject.downloadPdfResults(params)
    else
      PulseInsightsObject.backgroundCalls(true)
      window.PulseInsightsObject.jsonpGet "/submissions/#{submissionUdid}/all_answers", params, window.PulseInsightsObject.survey.allAnswersSubmitted
      PulseInsightsObject.backgroundCalls(false)

    false

  checkEmptyAnswers: ->
    survey = window.PulseInsightsObject.survey

    for answerContainer in document.querySelectorAll('._pi_answers_container')
      if survey.answerIsEmpty(answerContainer)
        survey.addEmptyAnswerAlert(answerContainer)
        survey.setAriaInvalid(answerContainer)

  addEmptyAnswerAlert: (answerContainer) ->
    survey = window.PulseInsightsObject.survey

    switch answerContainer.getAttribute('data-question-type')
      when 'free_text_question'
        survey.addFreeTextEmptyAnswerAlert(answerContainer)
      when 'multiple_choices_question'
        survey.addMultipleChoiceEmptyAnswerAlert(answerContainer)
      when 'single_choice_question'
        survey.addSingleChoiceEmptyAnswerAlert(answerContainer)
      when 'slider_question'
        survey.addAllAtOnceEmptyAnswerAlertForSlider(answerContainer)

  setAriaInvalid: (answerContainer) ->
    survey = window.PulseInsightsObject.survey

    switch answerContainer.getAttribute('data-question-type')
      when 'free_text_question'
        survey.setFreeTextAriaInvalid(answerContainer)
      when 'multiple_choices_question'
        survey.setMultipleChoicesAriaInvalid(answerContainer, 'true')
      when 'single_choice_question'
        survey.setSingleChoiceAriaInvalid(answerContainer)
      when 'slider_question'
        survey.setSliderAriaInvalid(answerContainer)

  focusOnFirstInvalidAnswer: ->
    widgetContentContainer = document.querySelector("#_pi_surveyWidget > div._pi_widgetContentContainer")
    ariaInvalidElement = widgetContentContainer.querySelector('[aria-invalid="true"]')
    ariaInvalidElement.focus() if ariaInvalidElement

  storeAnswer: (answerContainer) ->
    survey = window.PulseInsightsObject.survey
    survey.answers.push({question_id: answerContainer.getAttribute('data-question-id'), question_type: answerContainer.getAttribute('data-question-type'), answer: answerContainer.getAttribute('data-answer'), answer_content: answerContainer.getAttribute('data-answer-content') })

  checkSubmissionCompleteness: (answerContainer) ->
    survey = window.PulseInsightsObject.survey

    answerContainer.setAttribute('data-submit-error', true) if survey.answerIsInvalid(answerContainer)

    submissionCompleteness = true

    for answerContainer in document.querySelectorAll('._pi_answers_container')
      if survey.answerIsInvalid(answerContainer)
        submissionCompleteness = false
        break

    if submissionCompleteness
      survey.allSubmitButtonError.innerHTML = ''
      survey.allSubmitButton.removeAttribute('data-submit-error')
    else
      survey.allSubmitButton.setAttribute('data-submit-error', true)

  answerIsInvalid: (answerContainer) ->
    survey = window.PulseInsightsObject.survey
    survey.answerIsEmpty(answerContainer) || survey.answerContainsBannedData(answerContainer) || survey.answerCountExcessive(answerContainer)

  answerIsEmpty: (answerContainer) ->
    (answerContainer.getAttribute('data-answer') == null || answerContainer.getAttribute('data-answer') == '') &&
    answerContainer.getAttribute('data-question-optional') == 'f'

  answerContainsBannedData: (answerContainer) ->
    answerContainer.getAttribute('data-question-type') == 'free_text_question' &&
    this.personalDataMaskingEnabled() &&
    this.detectPersonalData(answerContainer.getAttribute('data-answer'))

  answerCountExcessive: (answerContainer) ->
    return false unless answerContainer.getAttribute('data-question-type') == 'multiple_choices_question'

    questionId = answerContainer.getAttribute('data-question-id')
    question = (q for q in @questions when q.id == parseInt(questionId))[0]
    return false unless question.maximum_selection?

    answerCount = answerContainer.getAttribute('data-answer').split(',').length
    answerCount > question.maximum_selection

  setControlTransitionFocus: (newValue) ->
    @controlTransitionFocus = newValue

  shouldControlFocus: (event) ->
    if window.PulseInsightsObject.isAndroid()
      return true
    else
      return event.detail == 0

  answerClicked: (event) ->
    event.stopPropagation()

    window.PulseInsightsObject.survey.setControlTransitionFocus(window.PulseInsightsObject.survey.shouldControlFocus(event))

    getAnswerId = (questionType) =>
      if questionType == '_pi_select'
        event.target.value
      else
        answer = window.PulseInsightsObject.survey.getAnswerElement(event.target)
        answer.getAttribute('data-answer-id')

    getAnswerContent = (questionType) =>
      if questionType == '_pi_select'
        selectTag = event.target
        selectTag.options[selectTag.selectedIndex].text
      else
        this.text

    getAnswerContainer = (questionType) =>
      if questionType == '_pi_select'
        event.target.parentNode
      else
        this.parentNode.parentNode

    questionType = event.target.getAttribute('class')
    answerId = getAnswerId questionType
    answerContent = getAnswerContent questionType
    answerContainer = getAnswerContainer questionType
    answerContainer.setAttribute 'data-answer', answerId
    answerContainer.setAttribute 'data-answer-content', answerContent

    window.PulseInsightsObject.survey.answerId = answerId
    if window.PulseInsightsObject.submission?
      submissionUdid = window.PulseInsightsObject.submission.udid
    else
      submissionUdid = null
    questionId = window.PulseInsightsObject.survey.question.id
    params =
      identifier: window.PulseInsightsObject.identifier
      question_id: questionId
      answer_id: answerId
      submission: JSON.stringify(window.PulseInsightsObject.submission)
      device_udid: window.PulseInsightsObject.udid

    # If there's custom data, send it along with the answer because
    #  it may have changed since the call to get the survey.
    if window.PulseInsightsObject.customData?
      params['custom_data'] = window.PulseInsightsObject.stringify(window.PulseInsightsObject.customData)
    if window.PulseInsightsObject.client_key
      params['client_key'] = window.PulseInsightsObject.getClientKey()

    if window.PulseInsightsObject.previewMode
      params['preview_mode'] = true
    else
      window.PulseInsightsObject.triggerOnAnswerCallback(event)

    window.PulseInsightsObject.jsonpGet "/submissions/#{submissionUdid}/answer", params, window.PulseInsightsObject.survey.answersSubmitted
    false

  customAnswersSubmitted: (data) ->
    window.PulseInsightsObject.survey.goToNextQuestion()

  answersSubmitted: (data) ->
    window.PulseInsightsObject.survey.goToNextQuestionOrThankYou(data)

  allAnswersSubmitted: (data) ->
    window.PulseInsightsObject.survey.thankYouOrResults(data)

  thankYouOrResults: (data) ->
    this.renderThankYou()

  goToNextQuestion: ->
    nextQuestionId = window.PulseInsightsObject.survey.next_question
    nextQuestion = (q for q in @questions when q.id == parseInt(nextQuestionId))[0]
    @question = nextQuestion
    @renderCurrentQuestion()
    return

  goToNextQuestionOrThankYou: (data) ->
    if @question.question_type in ['single_choice_question', 'slider_question']
      # Get the possible answer corresponding to @answerId
      possibleAnswer = (pa for pa in @question.possible_answers when pa.id == parseInt(@answerId))[0]

      # Saved the possible answer selected
      if not @answers?
        @answers = []
      @answers.push possibleAnswer

      if possibleAnswer.next_question_id?
        # Get next question
        nextQuestion = (q for q in @questions when q.id == possibleAnswer.next_question_id)[0]

        if nextQuestion?
          @question = nextQuestion
          @renderCurrentQuestion()
          return

    if @question.question_type == 'free_text_question' || @question.question_type == 'multiple_choices_question'
      answer = { }

      if @question.question_type == 'free_text_question'
        answer['content'] = window.PulseInsightsObject.survey.textInput.value if window.PulseInsightsObject.survey.textInput?
      else
        answer['content'] = PulseInsightsObject.survey.multipleChoiceAnswerIds(@question.id)
        multi_choice_other = @question.possible_answers.slice(-1)[0]

      if PulseInsightsObject.survey.multiChoiceOtherResponseHasFollowUp(multi_choice_other, answer) # when 'other' or 'something else' response has its own follow-up
        answer['next_question_id'] = multi_choice_other.next_question_id
      else if PulseInsightsObject.survey.multiChoiceQuestionHasFollowUp(@question) # use the question's next_question_id as direction for follow-up
        answer['next_question_id'] = @question.next_question_id

      if not @answers?
        @answers = []
      @answers.push answer if answer['content']

      if answer['next_question_id']?
        # Get next question
        nextQuestion = (q for q in @questions when q.id == answer['next_question_id'])[0]
        if nextQuestion?
          @question = nextQuestion
          @renderCurrentQuestion()
          return

    window.PulseInsightsObject.triggerOnCompleteCallback()

    if data? && (Object.keys(data).length > 0 && data.constructor == Array) # data contains results, show polls
      this.renderResults(data)
    else
      this.renderThankYou()

  multiChoiceOtherResponseHasFollowUp: (multi_choice_other, answer) ->
    return multi_choice_other? && multi_choice_other.next_question_id? &&
    multi_choice_other.next_question_id != 0 &&
    answer['content'].includes(multi_choice_other.id.toString())

  multiChoiceQuestionHasFollowUp: (question) ->
    return question.next_question_id? && question.next_question_id != 0

  startButtonClickedEvent: (e) ->
    e.stopPropagation()

    if @started?
      return false
    @started = true
    survey = window.PulseInsightsObject.survey
    survey.startButtonClicked.apply survey, []
    false

  startButtonClicked: ->
    @widgetContent.innerHTML = "<div class='_pi_loadingSurvey'>Loading...</div>"
    this.loadQuestions()

  widgetContainerClickedEvent: (e) ->
    e.stopPropagation()

  submitSurveyClosed: ->
    # Rack call to store the event (submission#closed_by_user)

    if window.PulseInsightsObject.submission
      submissionUdid = window.PulseInsightsObject.submission.udid
      window.PulseInsightsObject.jsonpGet "/submissions/#{submissionUdid}/close", { }, window.PulseInsightsObject.survey.surveyClosed

  closeButtonClickedEvent: (e) ->
    e.stopPropagation() if e != undefined

    survey = window.PulseInsightsObject.survey
    survey.submitSurveyClosed.apply survey, []
    survey.closeButtonClicked.apply survey, [e]
    false

  surveyClosed: (data) ->
    this.log "Survey closed"

  closeButtonClicked: (event) ->
    onCloseResult = window.PulseInsightsObject.triggerOnCloseCallback(event)

    if onCloseResult == "none defined"
      window.PulseInsightsObject.triggerOnCompleteCallback()

    @tearDownWidget()

  tearDownWidget: (msToClose=200) ->
    return unless @widget? && @widgetContainer?
    @widget.setAttribute 'style', "max-height: 0px"
    container = @widgetContainer

    # Prevent initialized exit intent trigger from firing
    window.PulseInsightsObject.ouibouncer?.disable()

    setTimeout ->
      container.setAttribute 'style', 'display: none;'
      widgetContentContainer = document.querySelector("#_pi_surveyWidget > div._pi_widgetContentContainer")
      question = document.querySelector("#_pi_surveyWidget > div._pi_widgetContentContainer > div._pi_question")
      answers_container = document.querySelector("#_pi_surveyWidget > div._pi_widgetContentContainer > ul._pi_answers_container")
      branding = document.querySelector("#_pi_surveyWidget > a._pi_branding")
      if (widgetContentContainer?)
        widgetContentContainer.style = 'display: none;'
      if (question?)
        question.style = 'display: none;'
      if (answers_container?)
        answers_container.style = 'display: none;'
      if (branding?)
        branding.style = 'display: none;'
    , msToClose
    false

#  widgetContainerClickedEvent: (e) ->
#    if e.target.tagName == "DIV" and e.target.getAttribute('id')=="_pi_surveyWidgetContainer"
#      window.PulseInsightsObject.survey.closeButtonClickedEvent(e)
#    false

  destroy: ->
    @tearDownWidget(0)
    if @widgetContainer? && document.getElementById(@widgetContainer.id) != null
      @widgetContainer.remove()

    # Remove CSS
    body = document.getElementsByTagName('body')[0]
    body.removeChild(css) for css in document.querySelectorAll("style.survey-#{this.id()}")
