import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../CollapsiblePanel';

import {updateLocalAndNodeProperties} from './QuestionSettingsPanelHelpers.js';

AnswerOrderPanel.propTypes = {
  node: PropTypes.object.isRequired,
  randomizationOptions: PropTypes.array.isRequired, // { label:, value:}
  lockPossibleAnswerOrderRandomization: PropTypes.bool.isRequired,
};

/**
 * The answer order options panel
 * New values won't make it into DOM until redraw,
 * so make sure canvas is redrawn when the modal is closed
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function AnswerOrderPanel(props) {
  const [randomizationActive, setRandomizationActive] = React.useState(
      props.node.question.randomize !== undefined &&
    props.node.question.randomize !== null,
  );

  const [randomizationValue, setRandomizationValue] = React.useState(
      props.node.question.randomize || props.randomizationOptions[0].value,
  );

  const [questionProperties, setQuestionProperties] = React.useState({
    randomize: props.node.question.randomize,
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  const onRandomizationToggled = (e) => {
    const checked = e.target.checked;

    setRandomizationActive(checked);

    if (checked) {
      onQuestionPropertyChange({randomize: randomizationValue});
    } else {
      onQuestionPropertyChange({randomize: null});
    }
  };

  const onSelectionChanged = (e) => {
    const newValue = e.target.value;

    setRandomizationValue(newValue);
    onQuestionPropertyChange({randomize: newValue});
  };

  /**
   * Render the possible answer randomization options
   * @return {JSX.Element} the options
   */
  function RandomizationOptions() {
    if (props.randomizationOptions.length === 1) {
      return props.randomizationOptions[0].label;
    } else {
      return (
        <select
          value={randomizationValue}
          onChange={onSelectionChanged}
          disabled={
            !randomizationActive ||
              props.lockPossibleAnswerOrderRandomization
          }
        >
          {
            props.randomizationOptions.map((option) => {
              return (
                <option
                  key={option.value}
                  value={option.value}
                >
                  {option.label}
                </option>
              );
            })
          }
        </select>
      );
    }
  };

  return (
    <CollapsiblePanel panelTitle='Answer Order'>
      <div className='options-row'>
        <input
          type="checkbox"
          // pass new value up to question for storage after modal's gone
          onChange={onRandomizationToggled}
          disabled={props.lockPossibleAnswerOrderRandomization}
          value={randomizationActive}
          checked={randomizationActive}
        />
        <span>Randomize order of</span>
        <RandomizationOptions />
      </div>
    </CollapsiblePanel>
  );
}

export default AnswerOrderPanel;
