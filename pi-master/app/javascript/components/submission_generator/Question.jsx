import React from 'react';
import PropTypes from 'prop-types';

import PossibleAnswers from './PossibleAnswers';

const Question = (props) => {
  return (
    <>
      <h2>
        { props.question.content }
      </h2>
      {
        props.question.possibleAnswers.length !== 0 ?
          <PossibleAnswers
            questionId={props.question.id}
            possibleAnswers={props.question.possibleAnswers}
          /> : null
      }
    </>
  );
};

Question.propTypes = {
  question: PropTypes.object.isRequired,
};

export default Question;
