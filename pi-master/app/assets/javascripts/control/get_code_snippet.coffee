$(document).ready ->
  if $('#web_toggle').length > 0
    $('#web_toggle').on 'click', (e) ->
      e.preventDefault()
      $('.dynamic-email-template-container').hide()
      $('.web-code-snippet-container').show()
      $('#dynamic_email_toggle').removeClass('selected')
      $(this).addClass('selected')

    $('#dynamic_email_toggle').on 'click', (e) ->
      e.preventDefault()
      $('.dynamic-email-template-container').show()
      $('.web-code-snippet-container').hide()
      $('#web_toggle').removeClass('selected')
      $(this).addClass('selected')
