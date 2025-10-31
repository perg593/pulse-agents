$(document).ready ->
  getElemValue = (elem) ->
    if elem.prop("type") == "checkbox"
      elem.prop('checked')
    else
      elem.val()

  handleLockedField = (cell) ->
    pauseRequested = window.confirm("The survey you are attempting to edit is currently Live. Would you like to change the status to “Paused” to enable editing?")

    # set the value of this survey's status selector and trigger the change event
    if pauseRequested
      if cell.hasClass("edit-possible-answer-locale-group-modal-cell") || cell.hasClass("edit-base-question-modal-cell")
        for statusField in $(".survey-status-selector")
          $statusField = $(statusField)
          if $statusField.val() == 'live'
            $statusField.val('paused').change()

        $(".locked").removeClass("locked")
      else
        columnIndex = cell.index()
        selectField = cell.closest("table").find("tr td:nth-child(" + (columnIndex + 1) + ") .survey-status-selector")
        selectField.val('paused').change()

  resizeTable = ->
    # Base survey column requires a fixed width,
    # so we must manually grow it when the theme dropdown overflows
    theme_dropdown = $("td:nth-child(2) .theme-input")
    rendered_dropdown_width = theme_dropdown.outerWidth()
    styled_dropdown_width = parseInt(theme_dropdown.css("min-width"))

    if rendered_dropdown_width > styled_dropdown_width
      extension = rendered_dropdown_width - styled_dropdown_width
      cell_width = parseInt(theme_dropdown.parent().css("max-width"))
      new_width = cell_width + extension

      for cell in $(".localization-table td:nth-child(2), .localization-table th:nth-child(2)")
        $cell = $(cell)
        $cell.css("width", new_width + "px")
        $cell.css("max-width", new_width + "px")

  initializeStickyHeader = ->
    $(document).on 'scroll', (e) ->
      header_cells = $("th")
      header_row = header_cells.parent("tr")

      navbar_height = $(".navbar").height()
      header_row_in_view = header_row.offset().top > $(window).scrollTop() + navbar_height

      if header_row_in_view
        header_cells.removeClass("sticky")
      else
        header_cells.addClass("sticky")
        header_cells.css({top: navbar_height })

  initializeTranslationTooltips = ->
    $(".translation-tooltip").hover (->
      elem = $(this)

      if elem.attr("data-original-title") == undefined || elem.attr("data-original-title") == ""
        $.ajax
          url: elem.attr('href'),
          type: 'GET',
          success: (data) ->
            elem.attr("data-original-title", data.translation)
            elem.tooltip("show")
          error: (jqXHR, textStatus, errorThrown) ->
            console.debug(errorThrown)
            console.debug(jqXHR.responseJSON.error)
            elem.attr("data-original-title", jqXHR.responseJSON.error)
            elem.tooltip("show")
    ), ->
      # noop

  initializeModals = ->
    openModalAsync = (elem, initFunc) ->
      cell = if elem[0].tagName == "TD" then elem else elem.parent("td")

      if cell.hasClass("locked")
        handleLockedField(cell)
        return

      modal_id = "#" + elem.data("modalId")

      if (elem.data("loaded"))
        modal = $(modal_id)
        modal.modal()
      else
        $.ajax
          url: elem.attr('href'),
          type: 'GET',
          success: (data) ->
            modal = $(modal_id + "_placeholder")
            modal.html(data)

            unless initFunc == undefined
              initFunc()

            modal = $(modal_id)
            modal.modal()
            elem.data("loaded", true)
          error: (jqXHR, textStatus, errorThrown) ->
            console.debug(errorThrown)
            console.debug(jqXHR.responseJSON.error)

    initializeModalCloseButton = (modal_id) ->
      $(modal_id + ".modal .trigger-close").on "click", (e) ->
        elem = $(this)

        if elem.data('persisted')
          elem.parent().find('input:checkbox[name$="[_destroy]"]').prop("checked", true)
          elem.parent().hide()
        else
          elem.parent().remove()

    initializeAddAnotherButton = (button_selector) ->
      $(button_selector).on "click", (e) ->
        index = $(this).parents('.basic-fields-container').find('.trigger-input').length

        $(this).siblings(".hidden-layout.trigger-input.hide").clone(true, true)
          .removeClass('hidden-layout hide')
          .insertBefore($(this))
          .find('input:text, select, input:hidden')
            .removeAttr('disabled')
            .attr('id', () ->
              return this.id.replace(/_attributes_\d+_/, '_attributes_' + index + '_' )
            )
            .attr('name', () ->
              return this.name.replace(/_attributes\]\[\d+\]\[/, '_attributes][' + index + '][' )
            )

    initializeLocaleGroupName = (modal_id="") ->
      $(modal_id + ' .base-content-input').on 'input', (e) ->
        elem = $(this)

        localeGroupNameInput = elem.parents('.modal-body').find('.locale-group-name')
        oldBaseValue = elem.data("lastVal")

        if (localeGroupNameInput.val() == "" || localeGroupNameInput.val() == oldBaseValue)
          localeGroupNameInput.val(elem.val())
          elem.data("lastVal", elem.val())

    initializeQuestionOptions = (modal_id) ->
      window.PulseInsightsConsole.QuestionFormatting.initQuestionOptions()
      modal = $(modal_id)

      # Consider doing this in Rails to save time
      modal.find(".question_fields_container.single_choice_question").find("input, select").removeAttr("disabled")
      modal.find(' #question_question_type').on 'change', (e) ->
        elem = $(this)

        question_fields_containers = modal.find(".question_fields_container")
        question_fields_containers.addClass("hidden")
        question_fields_containers.find("input, select").prop("disabled", "disabled")

        question_type_selector = elem.find("option:selected").data("questionTypeSelector")
        container_to_reveal = modal.find(".question_fields_container." + question_type_selector)

        container_to_reveal.removeClass("hidden")
        container_to_reveal.find("input, select").removeAttr("disabled")

    $(".edit-tag-modal-button").on 'click', (e) ->
      e.preventDefault()
      elem = $(this)
      modal_id = "#" + elem.data("modalId")
      openModalAsync(elem, () ->
        initializeTagEditor(modal_id, elem.siblings(".survey-tags-container"))
      )

    $(".image-modal-button").on 'click', (e) ->
      e.preventDefault()
      elem = $(this)
      modal_id = "#" + elem.data("modalId")
      openModalAsync(elem, () ->
        PulseInsightsConsole.initializeImageModals(modal_id)
      )

    $(".edit-url-triggers-modal-button, .edit-suppressers-modal-button, .custom-data-trigger-modal-button").on 'click', (e) ->
      e.preventDefault()
      elem = $(this)
      modal_id = "#" + elem.data("modalId")
      openModalAsync(elem, () ->
        initializeAddAnotherButton(modal_id + " .add_another_button")
        initializeModalCloseButton(modal_id)
      )

    $(".survey-image-modal-button").on 'click', (e) ->
      e.preventDefault()
      elem = $(this)
      modal_id = "#" + elem.data("modalId")
      openModalAsync(elem, () ->
        initializeColorPickers(modal_id)
      )

    $('.edit-possible-answer-locale-group-modal-cell').on 'dblclick', (e) ->
      elem = $(this)
      modal_id = "#" + elem.data("modalId")
      openModalAsync(elem, () ->
        initializeLocaleGroupName(modal_id)
      )

    $('.edit-base-question-modal-cell').on 'dblclick', (e) ->
      elem = $(this)
      modal_id = "#" + elem.data("modalId")
      openModalAsync(elem, () ->
        initializeQuestionOptions(modal_id)
      )

    $('.new-possible-answer-modal-button').on 'click', (e) ->
      e.preventDefault()
      elem = $(this)
      modal_id = "#" + elem.data("modalId")
      openModalAsync(elem, () ->
        initializeLocaleGroupName(modal_id)
      )

    $('.new-base-question-modal-button').on 'click', (e) ->
      e.preventDefault()
      elem = $(this)
      modal_id = "#" + elem.data("modalId")
      openModalAsync(elem, () ->
        initializeLocaleGroupName(modal_id)
        initializeQuestionOptions(modal_id)
      )

    $(".docked-widget-placement-modal-button, .survey-refire-modal-button").on 'click', (e) ->
      e.preventDefault()
      elem = $(this)
      openModalAsync(elem)

    $(".css-selector-trigger-modal-button").on 'click', (e) ->
      e.preventDefault()
      elem = $(this)
      openModalAsync(elem, () ->
        $(".modal-dialog.css-triggers :checkbox").on "change", (e) ->
          elem = $(this)
          new_value = elem.prop('checked')
          elem.siblings("input").attr("required", new_value)
      )

    $(".survey-css-modal-button").on 'click', (e) ->
      e.preventDefault()
      elem = $(this)
      modal_id = "#" + elem.data("modalId")
      openModalAsync(elem, () ->
        modal = $(modal_id)
        $(modal_id + " .css-selector-toggle-button").on 'click', (e) ->
          e.preventDefault()
          $(".css-selector-container, .css-selector-toggle-button", modal).toggleClass("hidden")
      )

  initializeRoutingHighlighting = ->
    handlePossibleAnswerHover = (elem, hovering) ->
      # possible answers
      elem.children(".glyphicon-triangle-bottom").toggleClass("hidden", !hovering)
      possible_answer_row = elem.parent("tr")
      possible_answer_row.toggleClass("highlighted", hovering)

      # questions
      selector = ".question-header-row[data-question-locale-group-id='" + possible_answer_row.data("nextQuestionLocaleGroupId") + "']"
      $(selector).toggleClass("highlighted", hovering)
      columnIndex = elem.index() + 1
      $(selector + " td:nth-child(" + columnIndex + ") .glyphicon-triangle-right").toggleClass("hidden", !hovering)

    handleQuestionHover = (elem, hovering) ->
      # questions
      elem.children(".glyphicon-triangle-right").toggleClass("hidden", !hovering)
      question_header_row = elem.parent("tr")
      question_header_row.toggleClass("highlighted", hovering)

      # possible answers
      possible_answer_row_selector = ".possible-answer-row[data-next-question-locale-group-id='" + question_header_row.data("questionLocaleGroupId") + "']"
      submit_label_row_selector = ".question-row.submit_label[data-next-question-locale-group-id='" + question_header_row.data("questionLocaleGroupId") + "']"

      $(possible_answer_row_selector + ", " + submit_label_row_selector).toggleClass("highlighted", hovering)
      columnIndex = elem.index() + 1
      possible_answer_arrow_selector = possible_answer_row_selector + " td:nth-child(" + columnIndex + ") .glyphicon-triangle-bottom"
      submit_label_arrow_selector = submit_label_row_selector + " td:nth-child(" + columnIndex + ") .glyphicon-triangle-bottom"

      $(possible_answer_arrow_selector + ", " + submit_label_arrow_selector).toggleClass("hidden", !hovering)

    $(".possible-answer-row:not(.last) td, .question-row.submit_label td").hover (->
      handlePossibleAnswerHover($(this), true)
    ), ->
      handlePossibleAnswerHover($(this), false)

    $(".question-header-row td").hover (->
      handleQuestionHover($(this), true)
    ), ->
      handleQuestionHover($(this), false)

  initializeColorPickers = (modal_id) ->
    $(modal_id + ' .color-box').colpick(
      colorScheme: 'dark'
      layout: 'rgbhex'
      onSubmit: (hsb, hex, rgb, el, bySetColor) ->
        $(el).css 'background-color', '#' + hex
        $(el).colpickHide()
        if !bySetColor
          $($(el).data('target')).val '#' + hex
        return
    ).css 'background-color', ->
      $(this).data 'color'

  initializeRowCollapsing = ->
    toggleRows = (elem, row_selector) ->
      $(row_selector).toggle()
      row_collapsed = $(row_selector).is(":visible")
      elem.toggleClass("glyphicon-plus-sign", !row_collapsed)
      elem.toggleClass("glyphicon-minus-sign", row_collapsed)

    $('.collapse-question-button').on 'click', (e) ->
      elem = $(this)
      row_selector = ".question_row_" + elem.data("questionLocaleGroupId")
      toggleRows(elem, row_selector)

    $(".toggle-rows-button").on 'click', (e) ->
      elem = $(this)
      row_selector = elem.data("rowSelector")
      toggleRows(elem, row_selector)

  initializeTagEditor = (parentTag, containerToUpdate) ->
    tagInputSelector = parentTag + ' select.applied-survey-tag-input'

    if ($(parentTag + " .select2").length == 0)
      for tagInput in $(tagInputSelector)
        $(tagInput).select2(tags: true)
        selected_values = $(tagInput).data('selectedValue')
        $(tagInput).val(selected_values).trigger('change')

      $(tagInputSelector).on 'change', (e) ->
        elem = $(this)

        data = {
          applied_survey_tags: elem.val()
        }

        $.ajax
          url: elem.attr('href'),
          data: data,
          type: 'POST',
          success: (data) ->
            containerToUpdate.html(data.tags)
          error: (jqXHR, textStatus, errorThrown) ->
            console.debug(errorThrown)

  initializeEditableCells = ->
    in_focus_cell = null

    # The inverse of the jQuery "param" function
    inverse_param = (param, value) ->
      # Three main cases to handle:
      # 'content', value # single value
      # 'questions_attributes[content]', value # value in hash
      # 'questions_attributes[possible_answers_attributes][][content]', value # value in array in hash
      #
      # result = { questions_attributes: { possible_answers_attributes: [{ content: value }]}}
      # jquery.param(result) == param
      result = {}

      # first key
      first_key = param.split("[")[0]

      # now to find subsequent keys
      # regex to find strings surrounded by '[]'
      regex = /\[.*?\]/g

      matches = param.matchAll(regex)

      match = matches.next()
      subsequent_keys = []

      while !match.done
        key = match.value[0].replace(/\[|\]/g, "")
        subsequent_keys.push(key)
        match = matches.next()

      keys = [first_key].concat(subsequent_keys)

      cur = result
      for key, i in keys
        if i == keys.length - 1
          cur[key] = value
        else if(key != "")
          if keys[i+1] == ""
            cur[key] = [{}]
            cur = cur[key][0]
          else
            cur[key] = {}
            cur = cur[key]

      result

    prepareData = (new_value, elem) ->
      data = {
        survey: {
        }
      }

      data.survey[elem.attr('name')] = new_value

      obj_param = inverse_param(elem.attr('name'), new_value)
      data.survey = obj_param

      extra_survey_attributes = elem.data('extraSurveyAttributes')
      data.survey = jQuery.extend(true, data.survey, extra_survey_attributes)

      data

    # compare base_value to new_value
    updateTooltip = (base_value, our_value, tooltip_selector) ->
      tooltip_selector.toggleClass("hidden", (base_value == undefined && our_value == undefined) || base_value.toString() == our_value.toString())

    updateTooltips = (elem, new_value, input_selector, broadcasted_change) ->
      row = elem.parents("tr")
      return unless row.data("hasDiffTooltip")

      if broadcasted_change
        row.data("baseValue", new_value)
        row.find(".diff-tooltip").addClass("hidden")
      else
        if elem.parents("td").hasClass("base")
          row.data("baseValue", new_value)

          for other_cell in row.children("td")
            other_cell_value = getElemValue($(other_cell).children(input_selector))
            if other_cell_value != undefined
              updateTooltip(new_value, other_cell_value, $(other_cell).children(".diff-tooltip"))
        else
          base_value = row.data("baseValue")
          updateTooltip(base_value, new_value, elem.siblings(".diff-tooltip"))

    submitEditableCell = (elem, input_selector, successHandler) ->
      new_value = getElemValue(elem)
      data = prepareData(new_value, elem)

      cell = elem.parent("td")
      broadcasted_change = cell.hasClass("base") && cell.data("broadcasted")

      if !broadcasted_change || window.confirm("This will apply the change to all surveys in the group. Proceed?")
        $.ajax
          url: elem.attr('href')
          data: data
          type: 'POST'
          success: (data) ->
            successHandler()
            updateTooltips(elem, new_value, input_selector, broadcasted_change)
          error: (jqXHR, textStatus, errorThrown) ->
            console.debug(errorThrown)
            console.debug(jqXHR.responseJSON.error)

    set_in_focus_cell = (cell) ->
      in_focus_cell = cell

    submitDatetime = (inputField) ->
      submitEditableCell(inputField, "input", () ->
        cell = inputField.parent("td")

        if cell.hasClass("base") && cell.data("broadcasted")
          cell.siblings("td").children("input").val(getElemValue(inputField))
      )

    $('input.survey_starts_at, input.survey_ends_at').focus ->
      elem = $(this)
      elem.datetimepicker(
        format: 'yyyy-mm-dd hh:ii',
        autoclose: true,
        showMeridian: false,
        pickerPosition: 'bottom-left',
        minView: 'day'
      )
      elem.datetimepicker 'show'
      elem.on 'hide', ->
        elem.datetimepicker 'remove'
      elem.data({oldValue: elem.val()})

    $('input.survey_starts_at, input.survey_ends_at').on 'change', (e) ->
      elem = $(this)

      if elem.parent("td").hasClass("locked")
        handleLockedField(elem.parent("td"))
        elem.val(elem.data("oldValue"))
        return

      submitDatetime($(this))

    $('input.survey_starts_at, input.survey_ends_at').on 'keydown', (e) ->
      elem = $(this)

      if (e.key == 'Escape')
        elem.val(elem.attr('value'))
      else if (e.key == 'Enter')
        submitDatetime(elem)

    $('td select.survey-status-selector').on 'change', (e) ->
      elem = $(this)
      oldValue = elem.data("oldValue")
      newValue = getElemValue(elem)

      if newValue != 'live' || window.confirm("Are you sure you want to set this survey Live? Press \"OK\" to proceed.")
        submitEditableCell(elem, "select", () ->
          elem.data("oldValue", newValue)

          cell = elem.parent("td")
          if cell.hasClass("base") && cell.data("broadcasted")
            same_row_inputs = cell.siblings("td").children("select")

            same_row_inputs.data("oldValue", newValue)
            same_row_inputs.val(newValue)

          columnIndex = cell.index()
          for columnCell in elem.closest("table").find("tr td:nth-child(" + (columnIndex + 1) + ").lockable")
            $(columnCell).toggleClass("locked", newValue == 'live')

          # if any survey is live, lock base locks
          baseModalTriggers = $('.edit-base-question-modal-cell, .edit-possible-answer-locale-group-modal-cell')
          if newValue == 'live'
            baseModalTriggers.addClass('locked')
          else
            noneLive = true
            for selectElement in $(".survey-status-selector")
              if ($(selectElement).val() == 'live')
                noneLive = false
                break

            if noneLive
              baseModalTriggers.removeClass('locked')
        )
      else
        elem.val(oldValue)

    $('td select:not(.applied-survey-tag-input, .survey-status-selector)').on 'focus', (e) ->
      elem = $(this)
      elem.data({oldValue: elem.val()})

    $('td select:not(.applied-survey-tag-input, .survey-status-selector)').on 'change', (e) ->
      elem = $(this)

      if elem.parent("td").hasClass("locked")
        handleLockedField(elem.parent("td"))
        elem.val(elem.data("oldValue"))
        return

      submitEditableCell(elem, "select", () ->
        new_value = getElemValue(elem)

        if elem.hasClass("widget-type-selector")
          $(".widget-row").addClass("hidden")
          $(".widget-row." + new_value).removeClass("hidden")

        cell = elem.parent("td")
        if cell.hasClass("base") && cell.data("broadcasted")
          cell.siblings("td").children("select").val(new_value)
      )

    $('td :checkbox').on 'focus', (e) ->
      elem = $(this)
      elem.data({oldValue: elem.prop("checked")})

    $('td :checkbox').on 'change', (e) ->
      elem = $(this)

      if elem.parent("td").hasClass("locked")
        handleLockedField(elem.parent("td"))
        elem.prop("checked", elem.data("oldValue"))
        return

      submitEditableCell(elem, ":checkbox", () ->
        if elem.hasClass("all-at-once-selector")
          $(".all-at-once-row").toggleClass("hidden")

        cell = elem.parent("td")
        if cell.hasClass("base") && cell.data("broadcasted")
          new_value = getElemValue(elem)
          cell.siblings("td").children(":checkbox").prop("checked", new_value)
      )

    $('.editable-cell').on 'dblclick', (e) ->
      cell = $(this)

      if cell.hasClass("locked")
        handleLockedField(cell)
        return

      set_in_focus_cell(cell)

      input = cell.find("input")
      input.show()
      input.focus()

      label = cell.find(".cell-label")
      label.hide()

    $('.editable-cell').on 'keydown', (e) ->
      cell = $(this)
      elem = cell.find('input')

      if (e.key == 'Escape')
        # abort edit
        # make sure input value is restored, i.e. prop is set to attr
        elem.val(elem.attr('value'))
        elem.hide()
        elem.siblings(".cell-label").show()
        set_in_focus_cell(null)
      else if (e.key == 'Enter')
        unless elem[0].checkValidity()
          return

        set_in_focus_cell(null)

        #consentRequired = cell.hasClass("language-code")
        consentRequired = false
        consented = false

        if consentRequired
          consented = window.confirm("Future content changes will be broadcast to all surveys in this group with the same (non-empty) language code. Are you sure you want to do this?")

        # check element for warnings, proceed when consent is received
        if !consentRequired || consented
          submitEditableCell(elem, "input", () ->
            elem.hide()
            cell_label = elem.siblings(".cell-label")
            cell_label.html(elem.val())
            cell_label.show()

            if cell.hasClass("language-code")
              columnIndex = cell.index()

              for columnCell in elem.closest("table").find("tr td:nth-child(" + (columnIndex + 1) + ")")
                $columnCell = $(columnCell)

                if $columnCell.attr("data-language-code")
                  $columnCell.attr("data-language-code", elem.val())
            # else if cell.hasClass("localized-content-cell")
              # language_code = cell.attr("data-language-code")
              #
              # same_language_cells = cell.parent("tr").children("td[data-language-code='" + language_code + "']")
              #
              # same_language_cells.children(".cell-label").html(elem.val())
              # same_language_cells.children("input").val(elem.val())
              #
              # same_language_cells.children(".translation-tooltip").attr("data-original-title", "")
              # same_language_cells.children(".translation-tooltip").toggleClass("hidden", elem.val() == "")
            else if cell.hasClass("base") && cell.data("broadcasted")
              same_row_cells = cell.siblings("td")

              same_row_cells.children(".cell-label").html(elem.val())
              same_row_cells.children("input").val(elem.val())
          )
        else
          elem.val(elem.attr('value'))
          elem.hide()
          elem.siblings(".cell-label").show()
          set_in_focus_cell(null)

    # Lose focus on cell when you click anywhere outside the cell
    $(document).on 'click', (e) ->
      if in_focus_cell && !$(e.target.closest('.editable-cell')).is(in_focus_cell)
        # break focus
        input = in_focus_cell.find('input')
        input.val(input.attr('value'))
        input.hide()
        input.siblings(".cell-label").show()
        set_in_focus_cell(null)

  if $(".localization-table").length > 0
    initializeModals()
    initializeRoutingHighlighting()
    initializeRowCollapsing()
    initializeEditableCells()
    initializeTranslationTooltips()
    initializeStickyHeader()
    resizeTable()

    $(".preview_link").on 'click', (e) ->
      e.preventDefault()
      survey_attributes = $(this).data("surveyAttributes")
      window.PulseInsightsObject.renderSurvey(survey_attributes)

    $(".toggle-overflow-button").on "click", (e) ->
      e.preventDefault()
      elem = $(this)
      elem.siblings("ul").children(".overflow").toggleClass("hidden")
      elem.siblings(".toggle-overflow-button").addBack().toggleClass("hidden")
