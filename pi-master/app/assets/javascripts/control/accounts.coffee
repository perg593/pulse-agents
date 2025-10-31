$("select.user_level").on 'change', (e) ->
  select = $(e.target)
  userLevel = select.val()

  select.fadeTo(0.1, 0.5).attr('disabled', 'disabled')

  ajaxOptions =
    url: select.data().url
    method: 'POST'
    dataType: 'json'
    data:
      _method: 'PATCH'
      user:
        level: userLevel
    success: (response) ->
      if response=="ok"
        select.fadeTo(0.1, 1.0).removeAttr('disabled')
        pulsate(select)
      else
        alert("Something went wrong: #{response}")

  $.ajax ajaxOptions

pulsate = (element) ->
  element.animate {'background-color': 'rgba(255,255,128,0.2)'}, 100, ->
    element.animate {'background-color': 'rgba(0,0,0,0)'}, 100

if $('.frequency-cap-inputs').length > 0
  if $('#user_frequency_cap_enabled').prop('checked')
    $('.frequency-cap-data').css('display', 'inline-block')

  $('#user_frequency_cap_enabled').on 'change', ->
    if $(this).prop('checked')
      $('.frequency-cap-data').css('display', 'inline-block')
    else
      $('.frequency-cap-data').hide()
