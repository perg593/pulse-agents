$(document).ready ->
  if $('.theme_css').length > 0
    editor = CodeMirror.fromTextArea(document.getElementById('theme_css'),
      extraKeys: 'Ctrl-Space': 'autocomplete'
      lineNumbers: true
    )
  if $('#theme-css-text').length > 0
    editor = CodeMirror.fromTextArea(document.getElementById('theme-css-text'),
      extraKeys: 'Ctrl-Space': 'autocomplete'
      lineNumbers: true
    )
  if editor
    editor.setOption('theme', 'monokai')
    cmResize(editor)

  if $('#theme_native_content').length > 0
    nativeEditor = CodeMirror.fromTextArea(document.getElementById('theme_native_content'),
      extraKeys: 'Ctrl-Space': 'autocomplete'
      lineNumbers: true
      mode: "application/json"
      lint: true
      gutters: ["CodeMirror-lint-markers"]
    )
  if $('#theme-native-text').length > 0
    nativeEditor = CodeMirror.fromTextArea(document.getElementById('theme-native-text'),
      extraKeys: 'Ctrl-Space': 'autocomplete'
      lineNumbers: true
      mode: "application/json"
      lint: true
      gutters: ["CodeMirror-lint-markers"]
    )
  if nativeEditor
    nativeEditor.setOption('theme', 'monokai')
    cmResize(nativeEditor)

  if $('.theme-new').length > 0
    # toggle inputs for CSS/JSON based on the selected type
    # default type is CSS
    $('.theme_native_content').hide()
    $('.theme_theme_type').change ->
      selected = $(this).find('select').val()
      if selected == 'native'
        $('.theme_css').hide()
        $('.theme_native_content').show()
      else if selected == 'css'
        $('.theme_css').show()
        $('.theme_native_content').hide()

