import React from 'react';
import PropTypes from 'prop-types';

import PossibleAnswer from './PossibleAnswer';

/**
 * Calculates the sum of an object's values
 * @param {object} container - object whose values will be totalled
 * @return {number} - the sum
 */
function sum(container) {
  return Object.values(container).reduce((sum, weight) => sum + weight);
}

const PossibleAnswers = (props) => {
  const [
    possibleAnswerWeights,
    setPossibleAnswerWeights,
  ] = React.useState(() => {
    const weightsById = {};

    props.possibleAnswers.forEach((possibleAnswer) => {
      weightsById[possibleAnswer.id] = Math.round(100 / props.possibleAnswers.length);
    });

    if (sum(weightsById) != 100) {
      weightsById[props.possibleAnswers[0].id] += 1;
    }

    return weightsById;
  });

  /**
   * Updates the weight hook
   * @param {number} possibleAnswerId -- ID of possible answer
   *   whose weight was changed
   * @param {number} newWeight -- The new weight value
   **/
  function updatePossibleAnswerWeights(possibleAnswerId, newWeight) {
    const newWeights = {...possibleAnswerWeights};

    newWeights[possibleAnswerId] = newWeight;

    setPossibleAnswerWeights(newWeights);
  }

  const weightsAreValid = sum(possibleAnswerWeights) === 100;

  return (
    <ul>
      {
        props.possibleAnswers.map((possibleAnswer) => {
          return (
            <PossibleAnswer
              key={possibleAnswer.id}
              possibleAnswer={possibleAnswer}
              questionId={props.questionId}
              updatePossibleAnswerWeights={updatePossibleAnswerWeights}
              defaultWeight={possibleAnswerWeights[possibleAnswer.id]}
              valid={weightsAreValid}
            />
          );
        })
      }
    </ul>
  );
};

PossibleAnswers.propTypes = {
  questionId: PropTypes.number.isRequired,
  possibleAnswers: PropTypes.array.isRequired,
};

export default PossibleAnswers;
