$(document).ready ->
  if $('.answers-list').length > 0
    selected = []
    answer_ids = []

    # Add text input to footer
    $('.answers-list tfoot th:not(.empty)').each ->
      searchElement = document.createElement('input')
      searchElement.setAttribute('type', 'text')
      searchElement.setAttribute('inputmode', 'numeric')
      searchElement.setAttribute('placeholder', 'Search')
      searchElement.setAttribute('pattern', '\\d*')

      this.appendChild(searchElement)
      return

    table = $('.answers-list').DataTable
      processing: true
      serverSide: true
      select: true
      iDisplayLength: 100
      dom: 'Bfrtip'
      ajax:
        data: (d) ->
          d.date_from = $('input#from').val()
          d.date_to = $('input#to').val()
          d.answer_ids = answer_ids
          return d
        url: '/admin/answers.json'
      createdRow: (row, data, index) ->
        $(row).attr('data-answer-id', data[5])
      columns: [
        { data: 0 },
        { data: 1 },
        { data: 2 },
        { data: 3 },
        { data: 4 },
        { data: 5 },
        { data: 6 },
        { data: 7 },
        { data: 8 },
        { data: 9 },
        { data: 10 },
        { data: 11 },
        { data: 12 },
        { data: 13 },
        { data: 14 },
        { data: 15 },
        { data: 16 }
      ]
      order: [[0, 'desc']]
      columnDefs: [
        {
          targets: [8, 9, 10, 11, 12, 13, 14, 15, 16],
          visible: false
        },
        {
          targets: '_all',
          render: $.fn.dataTable.render.text() # Render all untrusted output as text to protect datatable from XSS
        }
      ]
      buttons: [
        {
          text: 'Remove'
          className: 'btn btn-default'
          action: (e, dt, node, config) ->
            answer_ids = []
            for selected_tr in $('.selected')
              answer_ids.push $(selected_tr).data('answer-id')
            dt.ajax.reload() unless answer_ids.length == 0
        }
      ]

    applySearch = (tableColumn, searchValue) ->
      if tableColumn.search() != searchValue
        tableColumn.search(searchValue).draw()

    # Apply the search
    table.columns().every ->
      column = this
      inputElement = @footer().getElementsByTagName('input')[0]

      inputElement?.addEventListener 'keyup', (event) ->
        if this.checkValidity()
          applySearch(column, @value)

      inputElement?.addEventListener 'change', (event) ->
        if this.checkValidity()
          applySearch(column, @value)

    # Show/Hide column
    $('a.toggle-vis').on 'click', (e) ->
      e.preventDefault()
      # Get the column API object
      column = table.column($(this).attr('data-column'))
      # Toggle the visibility
      column.visible !column.visible()
      return

    # Select date range
    $('body').find('.input-daterange').datepicker(
      orientation: 'top right'
      format: 'yyyy-mm-dd')
      .on 'clearDate', (e) ->
        from = $('input#from').val()
        to = $('input#to').val()
        if from=='' && to==''
          table.draw()
        return
      .on 'changeDate', (e) ->
        from = $('input#from').val()
        to = $('input#to').val()
        if from && to
          table.draw()
        return
