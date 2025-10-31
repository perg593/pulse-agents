tooltipLowerCase = ->
  "Requires lower case character\n"

tooltipUpperCase = ->
  "Requires upper case character\n"

tooltipNumber = ->
  "Requires number\n"

tooltipSpecialChar = ->
  "Requires special character\n"

hasNumber = /\d/
hasUpperCase = /[A-Z]/
hasLowerCase = /[a-z]/
hasSpecialChar = /\W+/

tooltipTitle = (password) ->
  title = ''

  title += tooltipLowerCase()   unless hasLowerCase.test(password)
  title += tooltipUpperCase()   unless hasUpperCase.test(password)
  title += tooltipNumber()      unless hasNumber.test(password)
  title += tooltipSpecialChar() unless hasSpecialChar.test(password)

  title

$(".new_user[action='/sign_up']").find('#user_password').tooltip
  'title':  tooltipLowerCase() + tooltipUpperCase() + tooltipNumber() + tooltipSpecialChar()
  'placement': 'bottom'
  'trigger': 'focus'

$(".new_user[action='/sign_up']").find('#user_password').keyup ->
  password = $(this).val()

  if tooltipTitle(password) == ''
    $(this).tooltip('destroy')
    return

  $(this)
  .attr('title', tooltipTitle(password))
  .tooltip
    'placement': 'bottom'
    'trigger': 'focus'
  .tooltip 'fixTitle'
  .tooltip 'show'
