$(document).ready ->
  if $('.page-events').length > 0
    $('td > a').on 'ajax:success', (e, data, status, xhr) ->
      $(this).parent().parent().remove()
