import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../CollapsiblePanel';

import NumberFormat from 'react-number-format';
import {minValidation} from '../NumberValidations';

import AdditionalContentPanel from './AdditionalContentPanel';
import {updateLocalAndNodeProperties} from './QuestionSettingsPanelHelpers.js';

FreeTextPanel.propTypes = {
  node: PropTypes.object.isRequired,
  engine: PropTypes.object.isRequired,
};

/**
 * The free text question options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function FreeTextPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    hintText: props.node.question.hintText || '',
    submitLabel: props.node.question.submitLabel || props.node.defaultValue('submitLabel'),
    errorText: props.node.question.errorText || props.node.defaultValue('errorText'),
    emptyErrorText: props.node.question.emptyErrorText || props.node.defaultValue('emptyErrorText'),
    height: props.node.question.height || props.node.defaultValue('height'),
    maxLength: props.node.question.maxLength || props.node.defaultValue('maxLength'),
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  return (
    <>
      <CollapsiblePanel panelTitle='Free Text Options'>
        <div className='options-row'>
          <label htmlFor='hint_text'>Hint Text:</label>
          <input
            id='hint_text'
            className='free-text-hint-text'
            value={questionProperties.hintText}
            onChange={(e) => {
              onQuestionPropertyChange({hintText: e.target.value});
            }}
          />
        </div>

        <div className='options-row'>
          <label htmlFor='submit_label'>Submit Label:</label>
          <input
            id='submit_label'
            className='free-text-submit-text'
            value={questionProperties.submitLabel}
            onChange={(e) => {
              onQuestionPropertyChange({submitLabel: e.target.value});
            }}
          />
        </div>

        <div className='options-row'>
          <label
            htmlFor='error_text'
            title='Display when the user attempts to submit an answer with PII'
          >
            Error Text:
          </label>
          <input
            id='error_text'
            className='free-text-error-text'
            value={questionProperties.errorText}
            title='Display when the user attempts to submit an answer with PII'
            onChange={(e) => {
              onQuestionPropertyChange({errorText: e.target.value});
            }}
          />
        </div>

        <div className='options-row'>
          <label
            htmlFor='empty_error_text'
            title='Display when the user attempts to submit an empty answer'
          >
            Empty Error Text:
          </label>
          <input
            id='empty_error_text'
            className='free-text-empty-error-text'
            value={questionProperties.emptyErrorText}
            title='Display when the user attempts to submit an empty answer'
            onChange={(e) => {
              onQuestionPropertyChange({emptyErrorText: e.target.value});
            }}
          />
        </div>

        <div className='options-row'>
          <label html='line_height'>Input field rows:</label>
          <NumberFormat
            id='line_height'
            className='number-input'
            value={questionProperties.height}
            thousandSeparator={false}
            decimalSeparator={null}
            isAllowed={(values) => {
              return minValidation(values, 1);
            }}
            onBlur={(e) => {
              onQuestionPropertyChange({height: e.target.value});
            }}
          />
        </div>

        <div className='options-row'>
          <label html='max_length'>Max. length:</label>
          <NumberFormat
            id='max_length'
            className='number-input'
            value={questionProperties.maxLength}
            thousandSeparator={false}
            decimalSeparator={null}
            isAllowed={(values) => {
              return minValidation(values, 1);
            }}
            onBlur={(e) => onQuestionPropertyChange({maxLength: e.target.value})}
          />
        </div>
      </CollapsiblePanel>
      <AdditionalContentPanel node={props.node} engine={props.engine} />
    </>
  );
}

export default FreeTextPanel;
