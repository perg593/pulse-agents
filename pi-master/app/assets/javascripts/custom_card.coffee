$(document).ready ->
  autoFormat = ->
    editor = $('.CodeMirror')[0].CodeMirror
    totalLines = editor.lineCount()
    editor.autoFormatRange {
      line: 0
      ch: 0
    },
      line: totalLines - 1
      ch: editor.getLine(totalLines - 1).length
    return

  AddQuestionButton = (context) ->
    linkableQuestions = $('#question_custom_content').data('linkable-questions')
    ui = $.summernote.ui
    event = ui.buttonGroup([
      ui.button(
        contents: '<span class="fa fa-smile-o"></span>Link question <span class="caret"></span>'
        tooltip: 'Link to another question'
        data: toggle: 'dropdown')

      ui.dropdown(
        items: linkableQuestions.map (question) => $("<div>").text(question[1]).html() # HTML escaping with "text()" https://api.jquery.com/text/
        callback: (items) ->
          $(items).find('li a').on 'click', ->
            question = (q for q in linkableQuestions when q[1] is $(this).data('value'))[0]
            escapedQuestionContent = $("<div>").text(question[1]).html()
            context.invoke 'editor.pasteHTML', '<button class=\'pi_question_link\' data-question-id=' + question[0] + '>Go to question \"' + escapedQuestionContent + '\"</button>'
          return
      )
    ])
    event.render()

  sendFile = (file, callback) ->
    data = new FormData()
    data.append("file", file)
    $.ajax
      url: '/upload',
      data: data,
      cache: false,
      contentType: false,
      processData: false,
      dataType: 'json',
      type: 'POST',
      success: (data) ->
        callback(data)
    return


  $('textarea.summernote').summernote
    callbacks:
      onImageUpload: (files, editor, welEditable) ->
        sendFile files[0], (data) ->
          url = "#{data.scheme}://#{data.host}#{data.path}"
          $('.summernote').summernote('editor.insertImage', data.image)

    codemirror:
      theme: 'monokai'
      mode: 'htmlmixed'
      htmlMode: true
      lineNumbers: true
      tabMode: 'indent'
      tabSize: 2
    placeholder: 'Write here...'
    height: '500px'
    fontSizes: ['8', '9', '10', '11', '12', '14', '18', '24', '36', '48', '64', '82', '150']
    toolbar: [['style', ['style', 'addclass']], ['font', ['bold', 'italic', 'underline', 'clear']], ['fontname', ['fontname', 'fontsize']], ['color', ['color']],
      ['para', ['ul', 'ol', 'paragraph']], ['height', ['height']], ['table', ['table']], ['insert', ['link', 'picture', 'hr']], ['view', ['fullscreen', 'codeview']],
      ['link_question', ['add_question']], ['help', ['help']]]
    buttons:
      add_question: AddQuestionButton

  $('button.btn-codeview').click ->
    if $('.CodeMirror').length > 0
      autoFormat()

  # Update the editable to make sure it's updated from 'code view' version before saving
  $('.container-custom > button').click ->
    if $('.note-editable').is(':hidden')
      editor = $('.CodeMirror')[0].CodeMirror
      $('#question_custom_content').val editor.getValue()

  # Update the background color according to question's background color
  if $('#question_background_color').length > 0 && $('#question_background_color').val().length > 0
    $('.note-editable').css 'background', $('#question_background_color').val()
