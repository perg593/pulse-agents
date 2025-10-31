# Local Storage Library
#
# https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage
#

window.PulseInsightsInclude window.PulseInsights,
  supportsLocalStorage: ->
    try
      window.localStorage # this will cause an error on legacy browsers or browsers that are blocking this URL from using local storage
      return window.localStorage != null # this will be null if localStorage is disabled at the browser level
    catch e
      this.log(e)
      return false

  getItemFromStorage: (key) ->
    item = window.localStorage.getItem(key)

    if item != null
      this.log "Get item from Local Storage #{key}: #{item}"
      item
    else if item = this.readCookie(key)
      this.migrateFromCookieToStorage(key, item)
      item
    else
      this.log "#{key} was not found in Local Storage"
      null

  setItemInStorage: (key, item, force=false) ->
    if force
      this.log "Forcing storage of #{key}"
    # distinction between false and null is important
    else if this.getItemFromStorage(this.visitorTrackingKeyName()) == "false"
      return

    # error handling is strongly recommended -> https://developer.mozilla.org/en-US/docs/Web/API/Storage/setItem
    try
      item = item.toString()
      window.localStorage.setItem(key, item)
      this.log "Set item in Local Storage #{key}: #{item}"
    catch error
      this.log "Error while setting item in Local Storage: "+error

  removeItemFromStorage: (key) ->
    window.localStorage.removeItem(key)
    this.log "Remove item from Local Storage #{key}"

  migrateFromCookieToStorage: (key, item) ->
    this.setItemInStorage(key, item)
    this.eraseCookie(key)
    this.log "Cookie was migrated to Local Storage #{key}: #{item}"
