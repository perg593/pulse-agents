class window.BarSurvey extends window.Survey
  height: ->
    "auto"

  width: ->
    "100%"

  cssStyle: ->
    super() + "
      ._pi_invitationTextContainer {
        margin: 10px 20px;
        display: inline-block;
      }

      ._pi_startButton {
        display: inline-block;
        margin-top: 5px;
      }

      ._pi_loadingSurvey, ._pi_thankYouSurvey {
        #{this.fontCSS()}
        color: #{this.textColor()};
        margin: 50px 0px 80px 0px;
        text-align: center;
      }

      ._pi_surveyWidget {
        text-align: center;
        height: auto;
      }

      ._pi_widgetContentContainer {
        margin-left: auto;
        margin-right: auto;
        width: 960px;
        text-align: center;
      }

      ._pi_closeButton {
        padding: 8px;
      }

      @media screen and (max-width: 960px) {
        ._pi_widgetContentContainer {
          width: 100%;
        }
      }
    "
