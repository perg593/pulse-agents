$(document).ready ->
  if $('.panel .users').length > 0
    $('tr.user-details').hover (->
      $('.actions', $(this)).show()
      return
    ), ->
      $('.actions', $(this)).hide()
      return

  if $('.account-list').length > 0
    if $(".survey-search-form > input[name='keyword']").val() != ''
      data = { keyword: $(".survey-search-form > input[name='keyword']").val() }
    $.ajax
      url: '/admin/accounts/fetch_submissions',
      data: data,
      dataType: 'json',
      type: 'GET',
      success: (data) ->
        for object in data
          if object.account_id
            $submissions = $("tr[account-id=#{object.account_id}] > td[data-column='submissions']")
            $impressions = $("tr[account-id=#{object.account_id}] > td[data-column='impressions']")

            $submissions.attr('data-sort-value', object.submissions_size)
            $impressions.attr('data-sort-value', object.impressions_size)

            formatter = new Intl.NumberFormat()
            $submissions.text(formatter.format(object.submissions_size))
            $impressions.text(formatter.format(object.impressions_size))

  if $('.delete-account-user-button').length > 0

    $('.autocomplete-field').each ->
      autocompleteField = $(this)
      tags = autocompleteField.data('available-tags')

      autocompleteField.attr("size", autocompleteField.attr("placeholder").length)

      autocompleteField.autocomplete({
        delay: 0,
        source: tags,
        messages: {
          noResults: '',
          results: (_numResults) ->
        }
      })

    $('.delete-account-user-button').click (e) ->
      e.preventDefault()

      elem = $(this)

      numRows = elem.parent(".account-user-row").siblings(".account-user-row").length + 1
      if (numRows == 1)
        removeRow = confirm("By removing this user's last link, you will remove the user from the system. Proceed?")
        if (!removeRow)
          return

      inputField = $('#' + elem.data("selector-id"))

      $.ajax
        url: elem.attr('href'),
        type: 'DELETE',
        success: (data) ->
          if (removeRow)
            elem.parents("tr").remove()
          else
            elem.parent('.account-user-row').remove()
            inputField.autocomplete('option', { source: data })

    $('.add-account-user-button').click (e) ->
      e.preventDefault()

      elem = $(this)
      inputField = $('#' + elem.data("selector-id"))

      accountName = inputField.val()

      $.ajax
        url: elem.attr('href'),
        data: { account_name: accountName },
        type: 'POST'
        success: (data) ->
          inputField.autocomplete('option', { source: data.tags })

          template = inputField.siblings(".account-user-row").last()
          newRow = template.clone(true)
          newRow.children(".delete-account-user-button").attr("href", data.url)
          newRow.children(".account-name").html(accountName)
          newRow.insertAfter(template)
