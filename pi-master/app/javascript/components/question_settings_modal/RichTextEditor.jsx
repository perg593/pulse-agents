import React from 'react';
import PropTypes from 'prop-types';

import JoditEditor from 'jodit-react';
import OutsideClickHandler from 'react-outside-click-handler';

import {QuestionNodeModel} from '../react_diagram_extension/QuestionNodeModel';

/**
 * Escapes the given HTML
 * @param { String } html -- HTML to escape
 * @return { String } escaped HTML
 */
function escapeHTML(html) {
  const mereBox = document.createElement('div');
  mereBox.textContent = html; // "textContent" escapes HTML as needed: https://developer.mozilla.org/en-US/docs/Web/API/Node/textContent#differences_from_innerhtml
  return mereBox.innerHTML;
}

RichTextEditor.propTypes = {
  node: PropTypes.object.isRequired,
  engine: PropTypes.object.isRequired,
  questionProperties: PropTypes.object.isRequired,
  onQuestionPropertyChange: PropTypes.func.isRequired,
  questionPropertyName: PropTypes.string.isRequired,
};

/**
 * A rich text editor designed to edit question properties
 * @param { Object } props -- see propTypes
 * @return { JSX.Element } the editor
 */
function RichTextEditor(props) {
  const joditReference = React.useRef(null);
  const popupContainerRef = React.useRef(null);

  const questionLinkOptions = {};

  props.engine.getModel().getNodes().filter((node) => {
    return node !== props.node && node instanceof QuestionNodeModel;
  }).forEach((node) => {
    questionLinkOptions[node.question.content] = {
      data: {
        questionId: node.question.id,
        questionContent: escapeHTML(node.question.content), // Escaping to prevent XSS
      },
    };
  });

  // See https://xdsoft.net/jodit/doc/ for the complete set of options
  const JoditConfig = {
    readonly: false,
    hidePoweredByJodit: true,
    toolbarSticky: false,
    buttons: [
      'source',
      'link',
      'fontsize',
      'align',
      'bold',
      'italic',
      'underline',
      'ul',
      'ol',
      'image',
    ],
    toolbarAdaptive: false,
    extraButtons: [
      {
        text: 'Link question',
        tooltip: 'Link to another question',
        list: questionLinkOptions,
        exec: (editor, _control, originalEvent) => {
          // List item clicked
          if (originalEvent.control.args !== undefined) {
            const selectedOptionData = originalEvent.control.args[1].data;

            const questionId = selectedOptionData.questionId;
            const questionContent = selectedOptionData.questionContent;

            editor.selection.insertHTML(
                `<button class="pi_question_link" data-question-id="${questionId}">${questionContent}</button>`,
            );
          // Main button clicked
          } else {
            return false;
          }
        },
      },
    ],
    events: {
      afterInit(joditInstance) {
        joditReference.current = joditInstance;
      },
    },
  };

  /**
   * Determines whether click was on a JoditEditor popup
   *
   * @param { MouseEvent } e - The click event
   * @return { bool } whether or not the element is part of a JoditEditor popup
   **/
  function clickedToolbarButton(e) {
    return e.target.closest('.jodit-popup-container') !== null;
  }

  /**
   * Give Jodit popups a more useful parent
   **/
  function reparentToolbarPopup() {
    const popupContainer = document.getElementsByClassName('jodit-popup-container')[0];

    if (popupContainer !== undefined && popupContainerRef.current !== null) {
      popupContainerRef.current.appendChild(popupContainer);
    }
  }

  // Jodit's got a problem appending popups within the <dialog> element
  React.useEffect(() => {
    [...document.getElementsByClassName('jodit-toolbar-button')].forEach((toolbarButton) => {
      toolbarButton.addEventListener('click', (e) => {
        reparentToolbarPopup();
      });
    });
  }, null);

  return (
    <div className='question-settings-panel-content jodit-container'>
      <OutsideClickHandler
        onOutsideClick={(e) => {
          if (clickedToolbarButton(e)) {
            return;
          }

          const newValue = joditReference.current.getEditorValue();

          // TODO: Consider making this "has changed?" check more generally
          if (newValue !== props.questionProperties[props.questionPropertyName]) {
            const updatedQuestionProperty = {};
            updatedQuestionProperty[props.questionPropertyName] = newValue;
            props.onQuestionPropertyChange(updatedQuestionProperty);
          }
        }}
      >
        <JoditEditor
          ref={joditReference}
          value={props.questionProperties[props.questionPropertyName]}
          config={JoditConfig}
        />
        <div ref={popupContainerRef} />
      </OutsideClickHandler>
    </div>
  );
};

export default RichTextEditor;
