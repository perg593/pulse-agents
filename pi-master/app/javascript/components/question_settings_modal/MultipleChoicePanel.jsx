import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../CollapsiblePanel';

import NumberFormat from 'react-number-format';
import {minValidation, maxValidation} from '../NumberValidations';

import AdditionalContentPanel from './AdditionalContentPanel';
import AnswerOrderPanel from './AnswerOrderPanel';
import RadioButtonProperties from './RadioButtonProperties';
import {updateLocalAndNodeProperties} from './QuestionSettingsPanelHelpers.js';

MultipleChoicePanel.propTypes = {
  node: PropTypes.object.isRequired,
  engine: PropTypes.object.isRequired,
  lockPossibleAnswerOrderRandomization: PropTypes.bool.isRequired,
};

/**
 * The multiple choice question options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function MultipleChoicePanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    answersPerRowMobile: props.node.question.answersPerRowMobile,
    answersPerRowDesktop: props.node.question.answersPerRowDesktop,
    maximumSelection: props.node.question.maximumSelection || props.node.defaultValue('maximumSelection'),
    enableMaximumSelection: props.node.question.enableMaximumSelection || false,
    emptyErrorText: props.node.question.emptyErrorText || props.node.defaultValue('emptyErrorText'),
    submitLabel: props.node.question.submitLabel || props.node.defaultValue('submitLabel'),
    maximumSelectionsExceededErrorText: props.node.question.maximumSelectionsExceededErrorText || '',
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  const randomizationOptions = [
    {
      label: 'all responses, except the last',
      value: 1,
    },
  ];

  return (
    <>
      <AnswerOrderPanel
        node={props.node}
        randomizationOptions={randomizationOptions}
        lockPossibleAnswerOrderRandomization={props.lockPossibleAnswerOrderRandomization}
      />
      <CollapsiblePanel panelTitle='Multiple Choice Options'>
        <RadioButtonProperties
          questionProperties={questionProperties}
          onQuestionPropertyChange={onQuestionPropertyChange}
        />
        <div className='question-settings-panel-content'>
          <div className='options-row'>
            <input
              id='enable_maximum_selection_field'
              type="checkbox"
              onChange={(e) => {
                onQuestionPropertyChange({enableMaximumSelection: e.target.checked});
              }}
              value={questionProperties.enableMaximumSelection}
              checked={questionProperties.enableMaximumSelection}
            />
            <label
              htmlFor='enable_maximum_selection_field'
              className='full-width'
            >
              Enable maximum selection
            </label>
          </div>
          <div className='options-row'>
            <span>Allow a maximum of</span>
            <NumberFormat
              className='number-input'
              value={questionProperties.maximumSelection}
              thousandSeparator={false}
              decimalSeparator={null}
              isAllowed={(values) => {
                return minValidation(values, 2) &&
                  maxValidation(values, props.node.getNonDeletedPossibleAnswers().length);
              }}
              onBlur={(e) => {
                onQuestionPropertyChange({maximumSelection: e.target.value});
              }}
            />
            <span>selections</span>
          </div>

          <div className='options-row'>
            <label
              htmlFor='maximum_selections_exceeded_error_text'
              className='full-width'
              title='Display when the user selects too many answers'
            >
              Too many selections error text:
            </label>
            <input
              id='maximum_selections_exceeded_error_text'
              className='maximum-selections-exceeded-error-text'
              value={questionProperties.maximumSelectionsExceededErrorText}
              title='Display when the user selects too many answers'
              onChange={(e) => {
                onQuestionPropertyChange({maximumSelectionsExceededErrorText: e.target.value});
              }}
            />
          </div>

          <div className='options-row'>
            <label
              htmlFor='empty_error_text'
              className='full-width'
              title='Display when the user attempts to submit with no answer selected'
            >
              Empty error text:
            </label>
            <input
              id='empty_error_text'
              className='multiple-choice-empty-error-text'
              value={questionProperties.emptyErrorText}
              title='Display when the user attempts to submit with no answer selected'
              onChange={(e) => {
                onQuestionPropertyChange({emptyErrorText: e.target.value});
              }}
            />
          </div>

          <div className='options-row'>
            <label htmlFor='submit_label'>Submit Label:</label>
            <input
              id='submit_label'
              className='multiple-choice-submit-text'
              value={questionProperties.submitLabel}
              onChange={(e) => {
                onQuestionPropertyChange({submitLabel: e.target.value});
              }}
            />
          </div>
        </div>
      </CollapsiblePanel>
      <AdditionalContentPanel node={props.node} engine={props.engine} />
    </>
  );
}

export default MultipleChoicePanel;
