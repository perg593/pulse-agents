class window.TopBarSurvey extends window.BarSurvey
  widgetType: ->
    "topbarsurvey"

  widgetPositioning: ->
    "top: 0px;
     left: 0px;
     right: 0px;"

  cssStyle: ->
    super() + "
      #_pi_pusher {
        display: block;
      }

      ._pi_closeButton {
        top: 14px;
        width: 40px;
        height: 40px;
      }
    "

  render: ->
    super()

    if @attributes['pusher_enabled']=='false'
      this.log("Pusher Disabled")
      return
    else
      this.log("Pusher Enabled")

    # Pusher
    @pusher = document.createElement('div')
    @pusher.setAttribute 'id', '_pi_pusher'
    parent = document.getElementsByTagName('body')[0]
    parent.insertBefore @pusher, parent.firstChild

    redimensionPusher = ->
      pusher = document.getElementById('_pi_pusher')
      widget = document.getElementById('_pi_surveyWidget')
      widgetHeight = widget.offsetHeight
      pusher.setAttribute 'style', "height: #{widgetHeight}px;"

    @redimensionPusherInterval = setInterval redimensionPusher, 100

  closeButtonClicked: ->
    super()
    if @redimensionPusherInterval?
      setTimeout ->
        clearInterval @redimensionPusherInterval
        @redimensionPusherInterval = null
      , 1000
