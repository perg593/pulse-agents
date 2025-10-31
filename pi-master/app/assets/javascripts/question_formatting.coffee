window.PulseInsightsConsole.QuestionFormatting =
  initQuestionOptions: () ->
    $('a.options-link').off('click').on 'click', () ->
      link = $(event.target)
      optionsPanel = link.parents('.options')
      optionsPanel.toggleClass('expanded')
      false

    # Radio button
    setButtonRadio = (elem) ->
      return if $(elem).hasClass('active')

      $(elem).siblings('._pi_standard_button_outer').removeClass('active')
      $(elem).siblings('._pi_menu').removeClass('active')
      $(elem).parent().siblings('.hidden-answer-button-type').find('input').val('radio')
      $(elem).parent().siblings('.desktop-answer-width-type').find('#desktop-width-type-select').val('fixed')
      $(elem).parent().siblings('.desktop-answer-width-type').hide()
      $(elem).parent().siblings('.mobile-answer-width-type').find('#mobile-width-type-select').val('fixed')
      $(elem).parent().siblings('.mobile-answer-width-type').hide()
      $(elem).parent().siblings('.answer-alignment-type-desktop').hide()
      $(elem).parent().siblings('.answer-alignment-type-mobile').hide()
      $(elem).parent().siblings('.answer-per-row-mobile').show()
      $(elem).parent().siblings('.answer-per-row-mobile').find('input').val('2') unless $(elem).parent().siblings('.answer-per-row-mobile').find('input').val()
      $(elem).parent().siblings('.answer-per-row-desktop').find('input').val('3') unless $(elem).parent().siblings('.answer-per-row-desktop').find('input').val()
      $(elem).parent().siblings('.answer-per-row-desktop').show()
      $(elem).parent().siblings('.desktop-answer-options-label').show()
      $(elem).parent().siblings('.mobile-answer-options-label').show()
      $(elem).parent().siblings('.additional-text').hide()
      $(elem).parent().siblings('.single-choice-default-label').hide()
      $(elem).addClass('active')

    # Menu
    setMenu = (elem) ->
      return if $(elem).hasClass('active')

      $(elem).siblings('._pi_radio_button_outer').removeClass('active')
      $(elem).siblings('._pi_standard_button_outer').removeClass('active')

      $(elem).parent().siblings('.hidden-answer-button-type').find('input').val('menu')
      $(elem).parent().siblings('.desktop-answer-width-type').hide()
      $(elem).parent().siblings('.mobile-answer-width-type').hide()
      $(elem).parent().siblings('.answer-alignment-type-desktop').hide()
      $(elem).parent().siblings('.answer-alignment-type-mobile').hide()
      $(elem).parent().siblings('.answer-per-row-mobile').hide()
      $(elem).parent().siblings('.answer-per-row-desktop').hide()
      $(elem).parent().siblings('.desktop-answer-options-label').hide()
      $(elem).parent().siblings('.mobile-answer-options-label').hide()
      $(elem).parent().siblings('.additional-text').hide()
      $(elem).parent().siblings('.single-choice-default-label').show()
      $(elem).addClass('active')

    $('._pi_menu').click ->
      setMenu(this)

    $('._pi_radio_button_outer').click ->
      $(this).parent().siblings('.desktop-answer-options-label').removeClass('hidden')
      $(this).parent().siblings('.mobile-answer-options-label').removeClass('hidden')
      setButtonRadio(this)

    setDefaultValuesStandard = (desktop_width_type_select, mobile_width_type_select) ->
      unless desktop_width_type_select.val()
        desktop_width_type_select.val('fixed')
        desktop_width_type_select.parent().siblings('.answer-alignment-type-desktop').find('.fixed-center-alignment-type').removeClass('hidden')
        desktop_width_type_select.parent().siblings('.answer-per-row-desktop').find('input').val('3')
        desktop_width_type_select.parent().siblings('.answer-alignment-type-desktop').find('select').val('center')
      unless mobile_width_type_select.val()
        mobile_width_type_select.val('fixed')
        mobile_width_type_select.parent().siblings('.answer-alignment-type-mobile').find('.fixed-center-alignment-type').removeClass('hidden')
        mobile_width_type_select.parent().siblings('.answer-per-row-mobile').find('input').val('2')
        mobile_width_type_select.parent().siblings('.answer-alignment-type-mobile').find('select').val('center')

    # Standard button
    setButtonStandard = (elem) ->
      return if $(elem).hasClass('active')

      $(elem).siblings('.desktop-answer-options-label').show()
      $(elem).siblings('.mobile-answer-options-label').show()

      $(elem).siblings('._pi_radio_button_outer').removeClass('active')
      $(elem).siblings('._pi_menu').removeClass('active')
      $(elem).parent().siblings('.hidden-answer-button-type').find('input').val('standard')
      $(elem).parent().siblings('.desktop-answer-width-type').show()
      $(elem).parent().siblings('.mobile-answer-width-type').show()
      $(elem).parent().siblings('.answer-alignment-type-desktop').hide()
      $(elem).parent().siblings('.answer-alignment-type-mobile').hide()
      $(elem).parent().siblings('.answer-per-row-mobile').hide()
      $(elem).parent().siblings('.answer-per-row-desktop').hide()
      $(elem).parent().siblings('.desktop-answer-options-label').show()
      $(elem).parent().siblings('.mobile-answer-options-label').show()
      $(elem).parent().siblings('.additional-text').removeClass('hidden')
      $(elem).parent().siblings('.additional-text').show()
      $(elem).parent().siblings('.single-choice-default-label').hide()

      $desktop_width_type_select = $(elem).parent().siblings('.desktop-answer-width-type').find('#desktop-width-type-select')
      $mobile_width_type_select = $(elem).parent().siblings('.mobile-answer-width-type').find('#mobile-width-type-select')

      setDefaultValuesStandard($desktop_width_type_select, $mobile_width_type_select)

      if $desktop_width_type_select.val() == 'variable'
        $(elem).parent().siblings('.answer-alignment-type-desktop').show()
      else if $desktop_width_type_select.val() == 'fixed'
        $(elem).parent().siblings('.answer-per-row-desktop').show()
        $(elem).parent().siblings('.answer-alignment-type-desktop').show()

      if $mobile_width_type_select.val() == 'variable'
        $(elem).parent().siblings('.answer-alignment-type-mobile').show()
      else if $mobile_width_type_select.val() == 'fixed'
        $(elem).parent().siblings('.answer-per-row-mobile').show()
        $(elem).parent().siblings('.answer-alignment-type-mobile').show()

      $(elem).addClass('active')

    $('._pi_standard_button_outer').click ->
      $(this).parent().siblings('.desktop-answer-options-label').removeClass('hidden')
      $(this).parent().siblings('.mobile-answer-options-label').removeClass('hidden')
      setButtonStandard(this)

    # Change desktop alignment
    $('select#answers-alignment-desktop-select').change ->
      width_type = $(this).parent().siblings('.desktop-answer-width-type').find('select').val()

      $elem = $(this).siblings("." + width_type + '-' + $(this).val().replace('_', '-') + "-alignment-type")
      $elem.removeClass('hidden')
      $elem.addClass('active')
      $elem.siblings('.alignment-type').removeClass('active')
      $elem.siblings('.alignment-type').addClass('hidden')

    # Change desktop alignment
    $('select#answers-alignment-mobile-select').change ->
      width_type = $(this).parent().siblings('.mobile-answer-width-type').find('select').val()

      $elem = $(this).siblings("." + width_type + '-' + $(this).val().replace('_', '-') + "-alignment-type")
      $elem.removeClass('hidden')
      $elem.addClass('active')
      $elem.siblings('.alignment-type').removeClass('active')
      $elem.siblings('.alignment-type').addClass('hidden')

    # Desktop width type
    $('select#desktop-width-type-select').change ->
      $('select#answers-alignment-desktop-select').change()

      if $(this).val() == 'fixed'
        $(this).parent().siblings('.answer-per-row-desktop').show()
        $(this).parent().siblings('.answer-alignment-type-desktop').show()
      else if $(this).val() == 'variable'
        $(this).parent().siblings('.answer-per-row-desktop').hide()
        $(this).parent().siblings('.answer-alignment-type-desktop').show()
      else # empty val, hide everything
        $(this).parent().siblings('.answer-per-row-desktop').hide()
        $(this).parent().siblings('.answer-alignment-type-desktop').hide()

    # Mobile width type
    $('select#mobile-width-type-select').change ->
      $('select#answers-alignment-mobile-select').change()

      if $(this).val() == 'fixed'
        $(this).parent().siblings('.answer-per-row-mobile').show()
        $(this).parent().siblings('.answer-alignment-type-mobile').show()
      else if $(this).val() == 'variable'
        $(this).parent().siblings('.answer-per-row-mobile').hide()
        $(this).parent().siblings('.answer-alignment-type-mobile').show()
      else # empty val, hide everything
        $(this).parent().siblings('.answer-per-row-mobile').hide()
        $(this).parent().siblings('.answer-alignment-type-mobile').hide()

    $('input#question_fullscreen').click ->
      if @checked
        $(this).parents().children('.fullscreen-group').removeClass 'hide'
      else
        $(this).parents().children('#question_background_color').val ''
        $(this).parents().children('#question_opacity').val ''
        $(this).parents().children('.fullscreen-group').addClass 'hide'

    $('input#autoclose_enabled').click ->
      if @checked
        $(this).siblings("#autoclose_delay").removeAttr 'disabled'
      else
        $(this).siblings("#autoclose_delay").val ''

    $('input#autoredirect_enabled').click ->
      if @checked
        $(this).siblings("#autoredirect_url").removeAttr 'disabled'
        $(this).siblings("#autoredirect_delay").removeAttr 'disabled'
      else
        $(this).siblings("#autoredirect_delay").val ''
        $(this).siblings("#autoredirect_url").val ''

    for answer_options in $('.answers-options')
      if $(answer_options).find(".hidden-answer-button-type input").val() == 'radio'
        setButtonRadio($(answer_options).find('.answer-button-type ._pi_radio_button_outer'))
      else if $(answer_options).find(".hidden-answer-button-type input").val() == 'standard'
        setButtonStandard($(answer_options).find('.answer-button-type ._pi_standard_button_outer'))
      else if $(answer_options).find(".hidden-answer-button-type input").val() == 'menu'
        setMenu($(answer_options).find('.answer-button-type ._pi_menu'))

    handleAdditionalTextChange = (input, position) ->
      $items = if position == 'before' then $(input).siblings('input#before_answers_item') else $(input).siblings('input#after_answers_item')
      $other_items = if position == 'before' then $(input).parents('.additional-text').find('input#after_answers_item') else $(input).parents('.additional-text').find('input#before_answers_item')

      current_count = $items.not('.hidden').length
      new_count = parseInt($(input).val())

      if new_count > current_count
        $(input).parents('.additional-text').find('.icon-answers').removeClass('hidden')
        $newItem = $items.filter('.hidden').clone(true, true);
        $(input).parent().append($newItem)
        $newItem.removeClass('hidden')
        $newItem.removeClass('disabled')
        $newItem.removeAttr('disabled')
        $items = if position == 'before' then $(input).siblings('input#before_answers_item') else $(input).siblings('input#after_answers_item')
        $items.not('.hidden').attr('style', "width: calc((100% / #{new_count}) - (65px / #{new_count}) - 10px")
      else if new_count < current_count
        if new_count == 0 && $other_items.not('.hidden').length == 0
          $(input).parents('.additional-text').find('.icon-answers').addClass('hidden')
        for elem in $items.not('.hidden')[new_count..current_count]
          elem.remove()
        $items = if position == 'before' then $(input).siblings('input#before_answers_item') else $(input).siblings('input#after_answers_item')
        $items.not('.hidden').attr('style', "width: calc((100% / #{new_count}) - (65px / #{new_count}) - 10px")

    $(document).on 'keyup, mouseup, change', 'input#before_answers_count_input', ->
      handleAdditionalTextChange(this, 'before')

    $(document).on 'keyup, mouseup, change', 'input#after_answers_count_input', ->
      handleAdditionalTextChange(this, 'after')
