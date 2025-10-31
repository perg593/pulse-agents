$(document).ready ->
  if $('.show-more-audits-button').length > 0
    $('.show-more-audits-button').on 'click', ->
      $('.auditing-container.overflow').removeClass('hidden')
      $('.show-more-audits-button').hide()

  if $('.hide-more-audits-button').length > 0
    $('.hide-more-audits-button').on 'click', ->
      $('.auditing-container.overflow').addClass('hidden')
      $('.show-more-audits-button').show()
