class window.InlineSurvey extends window.Survey
  widgetType: ->
    "inlinesurvey"

  widgetParent: ->
    if PulseInsightsObject.isMobile() # take web value if mobile one is undefined
      inlineTargetSelector = @attributes['mobile_inline_target_selector'] || this.attributes['inline_target_selector']
    else
      inlineTargetSelector = @attributes['inline_target_selector']

    parent = null
    if inlineTargetSelector!=""
      if inlineTargetSelector.includes('::shadow')
        selectors = inlineTargetSelector.split('::shadow')
        currentParent = document

        for i in [0..selectors.length - 1]
          currentSelector = selectors[i]
          element = currentParent.querySelector(currentSelector)

          if element == null
            break

          if i == selectors.length - 1
            parent = element
          else
            currentParent = element.shadowRoot
            if currentParent == null
              break
      else
        parent = document.querySelector(inlineTargetSelector)

    if parent?
      this.log "Inline Target Area Found"
      parent

  cssStyle: ->
    super() + "
      #_pi_surveyWidget {
        position: relative;
      }

      ._pi_invitationTextContainer {
        margin: 30px 0px;
      }

      ._pi_startButton {
        display: block;
        width: 50%;
        margin-top: 50px;
        margin-left: auto;
        margin-right: auto;
        text-decoration: none;
      }

      ._pi_loadingSurvey, ._pi_thankYouSurvey {
        #{this.fontCSS()}
        color: #{this.textColor()};
        margin: 50px 0px 80px 0px;
        text-align: center;
      }

    "

  height: ->
    "150px"

  width: ->
    "100%"
