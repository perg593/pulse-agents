class window.DockedWidgetSurvey extends window.Survey
  widgetType: ->
    "dockedwidgetsurvey"

  widgetPositioning: ->
    if this.position().right?
      "right: #{this.position().right}"
    else
      "left: #{this.position().left}"

  cssStyle: ->
    super() +
    "
      #_pi_surveyWidget {
        border-top: 3px solid #{this.borderColor()};
        border-left: 3px solid #{this.borderColor()};
        border-right: 3px solid #{this.borderColor()};
        border-radius: 5px;
        bottom: -3px;
      }

      ._pi_invitationTextContainer {
        margin: 30px 0px;
      }

      ._pi_startButton {
        display: block;
        width: 50%;
        margin-top: 30px;
        margin-left: auto;
        margin-right: auto;
        margin-bottom: 60px;
        text-decoration: none;
      }

      ._pi_loadingSurvey, ._pi_thankYouSurvey {
        #{this.fontCSS()}
        color: #{this.textColor()};
        margin: 50px 0px 80px 0px;
      }
    "
