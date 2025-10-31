$(function() {
  // Submit search form
  $('input#keyword').on('keypress', function(event) {
    if (event.which === 13) {
      event.preventDefault();
      $(this).parent().submit();
    }
  });

  // Sorting
  $('.list-table').stupidtable().on('aftertablesort', function(event, data) {
    const $th = $(this).find('th');
    $th.find('.arrow').addClass('hide');
    const dir = $.fn.stupidtable.dir;

    const arrowClass = data.direction === dir.ASC ? 'arrow-up' : 'arrow-down';
    $th.eq(data.column).find('.arrow').removeClass('arrow-down arrow-up hide').addClass(arrowClass);
  });

  // Toggle actions for each row
  $('.list-table tbody tr').off('click').on('click', function(e) {
    const $this = $(e.currentTarget);
    if ($this.is(':hover')) {
      $('.actions, .status-actions', $this).show();
    } else {
      $('.actions, .status-actions', $this).toggle();
    }
  }).hover(
     function() {
        $('.actions, .status-actions', $(this)).show();
      },
      function() {
        $('.actions, .status-actions', $(this)).hide();
      },
  );
});
