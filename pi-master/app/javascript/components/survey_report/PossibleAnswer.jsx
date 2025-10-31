import React from 'react';
import PropTypes from 'prop-types';

import {activeStates} from './Common';

const ResultBarDeactivator  = (props) => {
  return (
    <div
      className='progress-bar-deactivator'
      onClick={() => {
        props.handlePossibleAnswerSelection(props.possibleAnswerId);
      }}
    >
      x
    </div>
  );
};

ResultBarDeactivator.propTypes = {
  handlePossibleAnswerSelection: PropTypes.func.isRequired,
  possibleAnswerId: PropTypes.number.isRequired,
};

const PossibleAnswer = (props) => {
  const active = props.activeState === activeStates.active;

  const AnswerRate = () => {
    return (
      <span>
        {new Intl.NumberFormat().format(props.possibleAnswer.answerCount)} ({props.possibleAnswer.answerRate}%)
      </span>
    );
  };

  const possibleAnswerColor = props.newColors[props.possibleAnswer.id] ||
    props.possibleAnswer.color;

  return (
    <div
      id={`possible-answer-anchor-${props.possibleAnswer.id}`}
      className='answer'
    >
      <p className='answer-content'>
        {props.possibleAnswer.content}
      </p>
      <div
        className='result-bar-wrapper'
      >
        {
          active ?
            <ResultBarDeactivator
              handlePossibleAnswerSelection={props.handlePossibleAnswerSelection}
              possibleAnswerId={props.possibleAnswer.id}
            /> :
            null
        }
        <div
          className='result-bar'
          style={{
            width: `${props.possibleAnswer.answerRate}%`,
            backgroundColor: possibleAnswerColor,
          }}
          onClick={() => {
            props.handlePossibleAnswerSelection(props.possibleAnswer.id);
          }}
        >
        </div>
        <div className='answer-rate'>
          <AnswerRate
            answerCount={props.possibleAnswer.answerCount}
            answerRate={props.possibleAnswer.answerRate}
          />
        </div>
      </div>
    </div>
  );
};

PossibleAnswer.propTypes = {
  possibleAnswer: PropTypes.object.isRequired,
  activeState: PropTypes.number.isRequired,
  newColors: PropTypes.object.isRequired,
  handlePossibleAnswerSelection: PropTypes.func.isRequired,
};

export default PossibleAnswer;
