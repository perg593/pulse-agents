$(document).ready ->
  $('tr.scheduled-survey-name').hover (->
    $('.actions', $(this)).show()
    return
  ), ->
    $('.actions', $(this)).hide()
    return

  $('.pi-formatted-date').each ->
    $elem = $(this)
    date = new Date(Number.parseInt($elem.html()))
    formatted_date = new Intl.DateTimeFormat([], {dateStyle: "long", timeStyle: "long"}).format(date)
    $elem.html(formatted_date)
