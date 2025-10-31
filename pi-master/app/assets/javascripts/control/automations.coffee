$(document).ready ->
  if $('.new-automation').length > 0
    # Switch condition_type/action_type when the other one has been changed because they should be fixed:
    # answer_text condtion & send_email action
    # url condition & create_event action
    $('.condition-type select').on 'change', (e) ->
      $('.answer_text, .url, .email, .event').toggleClass('hide')
      $('.action-type select :not(:selected)').prop('selected', true)
    $('.action-type select').on 'change', (e) ->
      $('.answer_text, .url, .email, .event').toggleClass('hide')
      $('.condition-type select :not(:selected)').prop('selected', true)

    $('a.add_another_btn').on 'click', (e) ->
      # The non-visible input is excluded because it's the template to create another input off of
      index = $('.url-matcher-input, .question-input:visible').length
      $button = $(e.currentTarget)
      $wrapper = $button.parent()
      $wrapper.find('.hidden-condition-layout')
      .clone(true, true)
      .removeClass('hidden-condition-layout hide')
      .insertBefore($button)
      .find('input:text, input:checkbox, select')
      .removeAttr('disabled')
      .attr('id', ->
        return @id.replace /_attributes_\d+_/, "_attributes_#{index}_"
      ).attr('name', ->
        return @name.replace /_attributes\]\[\d+\]\[/, "_attributes][#{index}]["
      )

    $('.condition-input a.close').on 'click', (e) ->
      $this = $(e.currentTarget)
      $parent = $this.parents('.automation-conditions-input')

      if $this.data('persisted')
        $parent.find('input:checkbox[name$="[_destroy]"]').prop("checked", true)
        $parent.hide()
      else
        $parent.remove()
