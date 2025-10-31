import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation} from '../NumberValidations';

import CollapsiblePanel from '../CollapsiblePanel';
import {updateLocalAndNodeProperties} from './QuestionSettingsPanelHelpers.js';

AdditionalTextPanel.propTypes = {
  node: PropTypes.object.isRequired,
};

/**
 * The additional text options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function AdditionalTextPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    beforeQuestionText: props.node.question.beforeQuestionText || '',
    afterQuestionText: props.node.question.afterQuestionText || '',
    beforeAnswersCount: props.node.question.beforeAnswersCount || 0,
    afterAnswersCount: props.node.question.afterAnswersCount || 0,
    beforeAnswersItems: props.node.question.beforeAnswersItems || [],
    afterAnswersItems: props.node.question.afterAnswersItems || [],
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  const onQuestionArrayPropertyChange = (e, name, index) => {
    const newItem = e.target.value;

    const newItems = [...questionProperties[name]];
    newItems[index] = newItem;

    const newObject = {};
    newObject[name] = newItems;

    onQuestionPropertyChange(newObject);
  };

  const AnswerItems = ({type, numberToRender}) => {
    const elements = [];

    for (let i = 0; i < numberToRender; i++) {
      const id = `${type}_answer_item_${i}`;
      elements.push(
          <div key={id} className='options-row'>
            <label htmlFor={id}>{i + 1}</label>
            <input
              id={id}
              defaultValue={questionProperties[type][i]}
              placeholder={`Label ${i + 1}`}
              onBlur={(e) => onQuestionArrayPropertyChange(e, type, i)}
            />
          </div>,
      );
    }

    return elements;
  };

  return (
    <CollapsiblePanel panelTitle='Additional Text'>
      <div className='options-row'>
        <label
          htmlFor='before_question_text'
        >
          Text Above Question
        </label>
        <input
          id='before_question_text'
          className='before-question-text-input'
          placeholder='E.g Please help us improve'
          value={questionProperties.beforeQuestionText}
          onChange={(e) => {
            onQuestionPropertyChange({beforeQuestionText: e.target.value});
          }}
        />
      </div>
      <div className='options-row additional-text'>
        <label
          htmlFor='after_question_text'
        >
          Text Below Question
        </label>
        <input
          id='after_question_text'
          className='after-question-text-input'
          placeholder='E.g Which of these most applies to you'
          value={questionProperties.afterQuestionText}
          onChange={(e) => {
            onQuestionPropertyChange({afterQuestionText: e.target.value});
          }}
        />
      </div>

      <div className='before-answers-wrapper'>
        <div className='options-row'>
          <label htmlFor='before_answers_count'>Labels Above Answers</label>
          <NumberFormat
            id='before_answers_count'
            className='number-input'
            value={questionProperties.beforeAnswersCount}
            thousandSeparator={false}
            decimalSeparator={null}
            isAllowed={(values) => {
              return minValidation(values, 1);
            }}
            onBlur={(e) => {
              onQuestionPropertyChange({beforeAnswersCount: e.target.value});
            }}
          />
        </div>
        <AnswerItems
          type='beforeAnswersItems'
          numberToRender={questionProperties.beforeAnswersCount}
        />
      </div>

      <div className='after-answers-wrapper'>
        <div className='options-row'>
          <label htmlFor='after_answers_count'>Labels Below Answers</label>
          <NumberFormat
            id='after_answers_count'
            className='number-input'
            value={questionProperties.afterAnswersCount}
            thousandSeparator={false}
            decimalSeparator={null}
            isAllowed={(values) => {
              return minValidation(values, 1);
            }}
            onBlur={(e) => {
              onQuestionPropertyChange({afterAnswersCount: e.target.value});
            }}
          />
        </div>
        <AnswerItems
          type='afterAnswersItems'
          numberToRender={questionProperties.afterAnswersCount}
        />
      </div>
    </CollapsiblePanel>
  );
}

export default AdditionalTextPanel;
