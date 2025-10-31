import React from 'react';
import PropTypes from 'prop-types';

import AdditionalTextPanel from './AdditionalTextPanel';
import CollapsiblePanel from '../CollapsiblePanel';

import AdditionalContentPanel from './AdditionalContentPanel';
import RadioButtonProperties from './RadioButtonProperties';
import {updateLocalAndNodeProperties} from './QuestionSettingsPanelHelpers.js';

NPSAnswerOptionsPanel.propTypes = {
  node: PropTypes.object.isRequired,
};

/**
 * The NPS Answer options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function NPSAnswerOptionsPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    answersPerRowMobile: props.node.question.answersPerRowMobile,
    answersPerRowDesktop: props.node.question.answersPerRowDesktop,
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  return (
    <CollapsiblePanel panelTitle='Answer Options'>
      <RadioButtonProperties
        questionProperties={questionProperties}
        onQuestionPropertyChange={onQuestionPropertyChange}
      />
    </CollapsiblePanel>
  );
}

NPSQuestionOptionsPanel.propTypes = {
  node: PropTypes.object.isRequired,
};

/**
 * The NPS question options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function NPSQuestionOptionsPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    emptyErrorText: props.node.question.emptyErrorText || props.node.defaultValue('emptyErrorText'),
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  return (
    <CollapsiblePanel panelTitle='NPS Question Options'>
      <div className='options-row'>
        <label
          htmlFor='empty_error_text'
          className='full-width'
          title='Display when the user attempts to submit with no answer selected'
        >
          Empty Error Text:
        </label>
        <input
          id='empty_error_text'
          className='nps-empty-error-text'
          value={questionProperties.emptyErrorText}
          title='Display when the user attempts to submit with no answer selected'
          onChange={(e) => {
            onQuestionPropertyChange({emptyErrorText: e.target.value});
          }}
        />
      </div>
    </CollapsiblePanel>
  );
}

NPSQuestionPanel.propTypes = {
  node: PropTypes.object.isRequired,
  engine: PropTypes.object.isRequired,
};

/**
 * The NPS question options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function NPSQuestionPanel(props) {
  return (
    <>
      <NPSAnswerOptionsPanel node={props.node} />
      <AdditionalTextPanel node={props.node} />
      <NPSQuestionOptionsPanel node={props.node} />
      <AdditionalContentPanel node={props.node} engine={props.engine} />
    </>
  );
}

export default NPSQuestionPanel;
