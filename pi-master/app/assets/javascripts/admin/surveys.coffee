window.PulseInsightsConsole =
  # private
  getImageScaledDimensions: (img) ->
    max_height = 250
    max_width = 250

    if img.height <= max_height && img.width <= max_width
      return [img.width, img.height]

    scale_height = max_height / img.height
    scale_width = max_width / img.width

    scale = Math.min(scale_width, scale_height)

    width = Math.round(img.width * scale)
    height = Math.round(img.height * scale)

    [width, height]

  stringToInteger: (number_text) ->
    digits = number_text.replace(/[^\d]/g, "")
    parseInt(digits)

  # public
  # Survey editor only has a single modal, but Localization editor will have many.
  # Localization editor needs to be able to initialize modals one at a time for performance reasons.
  initializeImageModals: (modal_id = "") ->
    # When closing the modal, we should hide the step2 to display the step1 on future re-opening
    $(modal_id + '.modal.possible_answer_image').on 'hidden.bs.modal', ->
      elem = $(this)
      elem.find('.possible-answer-modal-step1').removeClass('hidden')
      elem.find('.possible-answer-modal-step2').addClass('hidden')

    # Display error messages
    $(modal_id + ' .simple_form.possible_answer').on 'submit', (e) ->
      unless $(modal_id + ' .possible-answer-settings input[type=radio]').is(':checked')
        $(modal_id + ' .possible-answer-settings .error').text('This field is required')
        return false

    $(modal_id + ' .possible-answer-settings input[type=radio]').change ->
      $(modal_id + ' .possible-answer-settings .error').text('')

    # Click on 'NEXT' button in modal (step1 -> step 2)
    $(modal_id + ' .answer-image-next').click (e) ->
      elem = $(this)
      e.preventDefault()

      $(modal_id + ' .possible-answer-modal-step1').addClass('hidden')
      $(modal_id + ' .possible-answer-modal-step2').removeClass('hidden')

      form = elem.parents('form')

      selected_img_src = form.find('.possible-answer-image-wrapper.selected img').attr('src')
      height = form.find('#possible_answer_image_height').val()
      width = form.find('#possible_answer_image_width').val()

      new_image = $(modal_id + ' .preview-possible-answer-new-image')
      new_image.attr('src', selected_img_src)
      new_image.attr('height', height)
      new_image.attr('width', width)

      img = new Image()
      img.src = selected_img_src
      filename = selected_img_src.split("/").pop()

      $(modal_id + ' .preview-image-filename').text("#{filename} (#{img.width}x#{img.height})")

    # Click on 'BACK' button in modal (step2 -> step 1)
    $(modal_id + ' .answer-image-back').click (e) ->
      e.preventDefault()

      $(modal_id + ' .possible-answer-modal-step2').addClass('hidden')
      $(modal_id + ' .possible-answer-modal-step1').removeClass('hidden')

    $(modal_id + ' .image_settings_input').on 'change', (e) ->
      elem = $(this)
      $(modal_id + ' .image-positions').toggleClass('hidden', elem.val() != '1')

    # Click to select image position (top/bottom/left/right)
    $(modal_id + ' .image-position-wrapper').on 'click', ->
      elem = $(this)
      $(modal_id + ' .image-position-wrapper.selected').removeClass('selected')
      elem.addClass('selected')

      radio_button_index = null

      if elem.hasClass('top-position')
        radio_button_index = 0
      else if elem.hasClass('bottom-position')
        radio_button_index = 1
      else if elem.hasClass('right-position')
        radio_button_index = 2
      else if elem.hasClass('left-position')
        radio_button_index = 3

      elem.parents('.possible-answer-settings').find('#possible_answer_image_position_cd_' + radio_button_index).prop("checked", true)

    # Click on existing image, unselect previously selected image + populate height/width/id in form
    $(document).on 'click', modal_id + ' .possible-answer-image-wrapper', ->
      elem = $(this)
      elem.siblings().removeClass('selected')
      next_button = elem.parents(modal_id + '.modal.possible_answer_image').find('.answer-image-next')
      form = elem.parents('form')

      # Unselect the image if already selected
      if elem.hasClass('selected')
        form.find('input.possible_answer_answer_image_id').val('')
        elem.removeClass('selected')
        next_button.attr('disabled', 'disabled')
      else
        next_button.removeAttr('disabled')

        img = new Image()
        img.src = elem.find('img').attr('src')

        scaled_dimensions = PulseInsightsConsole.getImageScaledDimensions(img)
        width = scaled_dimensions[0]
        height = scaled_dimensions[1]

        form.find('input.possible_answer_image_width').val("#{width}px")
        form.find('input.possible_answer_image_height').val("#{height}px")

        form.find('input.possible_answer_image_width_mobile').val("#{width}px")
        form.find('input.possible_answer_image_height_mobile').val("#{height}px")

        form.find('input.possible_answer_image_width_tablet').val("#{width}px")
        form.find('input.possible_answer_image_height_tablet').val("#{height}px")

        form.find('input.possible_answer_image_alt').val(elem.find('img').attr('alt'))
        form.find('input.possible_answer_answer_image_id').val(elem.find('img').data('id'))

        elem.addClass('selected')

    # Upon uploading new image
    $(modal_id + ' input.file.optional').change ->
      return unless this.files && this.files[0]

      reader = new FileReader()
      that = this

      size_error = $(modal_id + '.possible_answer_image .size-error')

      if this.files[0].size / (1000 * 1000) > 3
        size_error.removeClass('hidden')
        return
      else
        size_error.addClass('hidden')

      reader.onload = (e) ->
        img = new Image()
        img.src = reader.result
        img.onload = ->
          $(that).parents(modal_id + '.modal.possible_answer_image').find('.answer-image-next').removeAttr('disabled')

          scaled_dimensions = PulseInsightsConsole.getImageScaledDimensions(img)
          width = scaled_dimensions[0]
          height = scaled_dimensions[1]

          new_image = $(that).parents('.possible-answer-new-image')

          # update height and width inputs with new image sizes
          new_image.find('input.possible_answer_image_height').val(height)
          new_image.find('input.possible_answer_image_width').val(width)

          # update height and width of other images
          possible_answer_images = new_image.siblings('.possible-answer-images').find('img')
          possible_answer_images.attr('height', height)
          possible_answer_images.attr('width', width)

          # preview image
          new_image_img = new_image.find('img')
          new_image_img.addClass('selected')
          new_image_img.removeClass('hidden')
          new_image_img.attr('height', height)
          new_image_img.attr('width', width)
          new_image_img.attr('src', e.target.result)

          $(modal_id + ' .possible-answer-image-wrapper.selected').removeClass('selected')

          $(modal_id + ' .possible-answer-images').prepend("<div class='possible-answer-image-wrapper selected'>
            <img class='other-possible-answer-image' src='#{e.target.result}'>
          </div>")

      reader.readAsDataURL(this.files[0])

$(document).ready ->
  if $('.survey-formatting').length > 0
    current_status = $('#survey_status').find(':selected').text()

    $('input.btn.btn-default').on 'click', ->
      selected = $('#survey_status').find(':selected').text()
      if selected == 'Live' && current_status != 'Live'
        window.confirm('Are you sure you want to set this survey Live? Press "OK" to proceed.')
