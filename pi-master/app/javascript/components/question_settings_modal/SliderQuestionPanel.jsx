import React from 'react';
import PropTypes from 'prop-types';

import Nouislider from "nouislider-react";

import CollapsiblePanel from '../CollapsiblePanel';
import {updateLocalAndNodeProperties} from './QuestionSettingsPanelHelpers.js';

SliderQuestionPanel.propTypes = {
  node: PropTypes.object.isRequired,
};

/**
 * The slider question panel
 * @param { Object } props
 * @return { JSX.Element } the panel
 */
function SliderQuestionPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    sliderStartPosition: props.node.question.sliderStartPosition,
    sliderSubmitButtonEnabled: props.node.question.sliderSubmitButtonEnabled,
    submitLabel: props.node.question.submitLabel || props.node.defaultValue('submitLabel'),
    emptyErrorText: props.node.question.emptyErrorText || props.node.defaultValue('emptyErrorText'),
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  return (
    <>
      <CollapsiblePanel panelTitle='Slider' panelClass='slider-question-panel'>
        <Nouislider
          start={parseInt(questionProperties.sliderStartPosition)}
          range={
            {
              'min': 0,
              'max': props.node.getNonDeletedPossibleAnswers().length - 1,
            }
          }
          connect={'upper'}
          step={1}
          pips={
            {
              'mode': 'count',
              'values': props.node.getNonDeletedPossibleAnswers().length,
              // Making sub pips invisible https://refreshless.com/nouislider/pips/#section-steps
              // Usually main pips are Integer(e.g. 3) and sub pips are 2 decimal Float(e.g. 3.24), but there's a bug where a main pip holds too many decimals(e.g. 3.00000001) https://stackoverflow.com/q/44210566/12065544
              'filter': (value, _type) => Number.isInteger(parseFloat(value.toFixed(2))) ? 1 : -1,
              'format': {
                'to': (position) => props.node.getNonDeletedPossibleAnswers().find((possibleAnswer) => possibleAnswer.position === parseInt(position)).content,
              },
            }
          }
        />
      </CollapsiblePanel>
      <CollapsiblePanel panelTitle='Options'>
        <div className='options-row'>
          <span>Start Position: </span>
          <select
            value={questionProperties.sliderStartPosition}
            onChange={(e) => {
              onQuestionPropertyChange({sliderStartPosition: e.target.value});
            }}
          >
            {
              props.node.getNonDeletedPossibleAnswers().map((possibleAnswer) => {
                return (
                  <option
                    key={possibleAnswer.position}
                    value={possibleAnswer.position}
                  >
                    {possibleAnswer.content}
                  </option>
                );
              })
            }
          </select>
        </div>
        <div className='options-row'>
          <label>Show Submit Button:</label>
          <input
            type="checkbox"
            onChange={(e) => {
              onQuestionPropertyChange({sliderSubmitButtonEnabled: e.target.checked});
            }}
            value={questionProperties.sliderSubmitButtonEnabled}
            checked={questionProperties.sliderSubmitButtonEnabled}
          />
        </div>
        <div className='options-row'>
          <label>Submit Label:</label>
          <input
            value={questionProperties.submitLabel}
            onChange={(e) => {
              onQuestionPropertyChange({submitLabel: e.target.value});
            }}
          />
        </div>
        <div className='options-row'>
          <label>Empty Error Text:</label>
          <input
            value={questionProperties.emptyErrorText}
            onChange={(e) => {
              onQuestionPropertyChange({emptyErrorText: e.target.value});
            }}
          />
        </div>
      </CollapsiblePanel>
    </>
  );
}

export default SliderQuestionPanel;
