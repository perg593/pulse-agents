# Simple library to create, read and erase cookies
#
# Reference: http://www.quirksmode.org/js/cookies.html
#

window.PulseInsightsInclude window.PulseInsights,
  createCookie: (name, value, minutes) ->
    if (minutes)
      date = new Date()
      date.setTime date.getTime()+(minutes*60*1000)
      expires = "; expires=" + date.toGMTString()
    else
      expires = "";

    cookie = name+"="+value+expires+"; path=/"
    this.log "Creating cookie #{cookie}"
    document.cookie = cookie

  readCookie: (name) ->
    nameEQ = name + "="
    pi = this
    value = null
    findCookie = (c) ->
      c = c.substring 1, c.length while c.charAt(0) == ' '
      if (c.indexOf(nameEQ) == 0)
        value = c.substring nameEQ.length, c.length

    findCookie c for c in document.cookie.split(';')
    this.log "Read cookie #{name}: #{value}"
    value

  eraseCookie: (name) ->
    this.createCookie name, "", -1
