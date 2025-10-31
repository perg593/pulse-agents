class window.FullscreenSurvey extends window.Survey
  widgetType: ->
    "fullscreensurvey"

  widgetPositioning: ->
    if this.attributes.fullscreen_margin
      double_margin = parseInt(this.attributes.fullscreen_margin) * 2

      "top: 0px;
       left: 0px;
       margin: #{this.attributes.fullscreen_margin}%;
       width: calc(100% - #{double_margin}%) !important;
       position: fixed;
       display: flex !important;
       flex-direction: column !important;
       flex-wrap: nowrap !important;
       justify-content: space-between !important;
       align-items: center !important;
       align-content: center !important;"
    else
      "top: 0px;
       left: 0px;
       width: 100% !important;
       height: 100% !important;
       position: fixed;
       display: flex !important;
       flex-direction: column !important;
       flex-wrap: nowrap !important;
       justify-content: space-between !important;
       align-items: center !important;
       align-content: center !important;"

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

  mobileCssStyle: ->
    super() + "
      ._pi_closeButton {
        padding: 0;
      }
      #_pi_surveyWidgetContainer.mobile-enabled #_pi_surveyWidget {
        top: 0px;
        left: 0px;
        width: 100% !important;
        height: 100% !important;
        position: fixed;
        display: flex !important;
        flex-direction: column !important;
        flex-wrap: nowrap !important;
        justify-content: space-between !important;
        align-items: center !important;
	      align-content: center !important;
	      border: none;
	      margin: 0;
      }
      "
