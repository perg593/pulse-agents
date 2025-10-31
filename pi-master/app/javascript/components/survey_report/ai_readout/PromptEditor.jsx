import React from 'react';
import PropTypes from 'prop-types';

const PromptEditor = ({
  promptText,
  showPromptEditor,
  setShowPromptEditor,
  isLoading,
  onSaveEditedPrompt,
}) => {
  const textareaRef = React.useRef(null);

  const handleBlur = () => {
    if (onSaveEditedPrompt && textareaRef.current) {
      const currentValue = textareaRef.current.value;
      if (currentValue !== promptText) {
        onSaveEditedPrompt(currentValue);
      }
    }
  };

  return (
  <div className="prompt-editor">
    <div className="prompt-header">
      <label htmlFor="prompt-text">Prompt:</label>
      <button
        type="button"
        className="inconspicuous-button"
        onClick={() => {
          if (!showPromptEditor) {
            // When opening editor, set the textarea value to current prompt
            if (textareaRef.current) {
              textareaRef.current.value = promptText;
            }
          } else {
            // Save the edited prompt when hiding the editor
            handleBlur();
          }
          setShowPromptEditor(!showPromptEditor);
        }}
      >
        {showPromptEditor ? 'Hide Editor' : 'Edit Prompt'}
      </button>
    </div>

    {
      showPromptEditor ? (
        <textarea
          ref={textareaRef}
          id="prompt-text"
          className='editor'
          defaultValue={promptText}
          onBlur={handleBlur}
          disabled={isLoading}
          rows={8}
          placeholder="Enter your prompt here..."
        />
      ) : (
        <pre className="preview-container">
          {promptText || 'No prompt selected'}
        </pre>
      )
    }
  </div>
  );
};

PromptEditor.propTypes = {
  promptText: PropTypes.string.isRequired,
  showPromptEditor: PropTypes.bool.isRequired,
  setShowPromptEditor: PropTypes.func.isRequired,
  isLoading: PropTypes.bool.isRequired,
  onSaveEditedPrompt: PropTypes.func,
};

export default PromptEditor;
