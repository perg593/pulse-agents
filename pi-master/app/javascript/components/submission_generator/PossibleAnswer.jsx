import React from 'react';
import PropTypes from 'prop-types';

const PossibleAnswer = (props) => {
  const context = `possible_answer_weights[${props.questionId}][]`;

  const weightInput = React.useRef(null);

  React.useLayoutEffect(() => {
    const domNode = weightInput.current;

    if (!props.valid) {
      domNode.setCustomValidity('Must add to 100');
      domNode.reportValidity();
    } else {
      domNode.setCustomValidity('');
    }
  }, [props.valid]);

  /**
   * Validates the possible answer fields and shows error
   * messages when appropriate
   * @param { Element } field -- the input field to validate
   */
  function validateSyntax(field) {
    if (field.validity.patternMismatch) {
      field.setCustomValidity('Whole numbers, please');
      field.reportValidity();
    }
  }

  return (
    <li key={props.possibleAnswer.id} >
      { props.possibleAnswer.content }:
      <input
        id={`possible_answer_weight_${props.possibleAnswer.id}`}
        name={`${context}[weight]`}
        defaultValue={props.defaultWeight}
        inputMode='numeric'
        pattern='\d*'
        required
        onChange={(e) => {
          const field = e.target;
          validateSyntax(field);
        }}
        onBlur={(e) => {
          const field = e.target;
          const weight = parseInt(field.value);

          props.updatePossibleAnswerWeights(props.possibleAnswer.id, weight);
        }}
        ref={weightInput}
      >
      </input>
      <input
        type='hidden'
        name={`${context}[possible_answer_id]`}
        value={props.possibleAnswer.id}
      >
      </input>
    </li>
  );
};

PossibleAnswer.propTypes = {
  questionId: PropTypes.number.isRequired,
  possibleAnswer: PropTypes.object.isRequired,
  updatePossibleAnswerWeights: PropTypes.func.isRequired,
  defaultWeight: PropTypes.number.isRequired,
  valid: PropTypes.bool.isRequired,
};

export default PossibleAnswer;
