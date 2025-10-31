import React from 'react';
import PropTypes from 'prop-types';

import CustomContentOptionsPanel from './CustomContentOptionsPanel';
import MultipleChoicePanel from './MultipleChoicePanel';
import FreeTextPanel from './FreeTextPanel';
import SingleChoiceQuestionPanel from './SingleChoiceQuestionPanel';
import NPSQuestionPanel from './NPSQuestionPanel';
import SliderQuestionPanel from './SliderQuestionPanel';

QuestionTypeOptions.propTypes = {
  node: PropTypes.object.isRequired,
  engine: PropTypes.object.isRequired,
  lockPossibleAnswerOrderRandomization: PropTypes.bool.isRequired,
};

/**
 * The top-level wrapper for question settings
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function QuestionTypeOptions(props) {
  if (props.node.question.nps) {
    return (
      <NPSQuestionPanel
        node={props.node}
        engine={props.engine}
      />
    );
  }

  switch (props.node.question.type.value) {
    case 'single_choice_question':
      return (
        <SingleChoiceQuestionPanel
          node={props.node}
          engine={props.engine}
          lockPossibleAnswerOrderRandomization={props.lockPossibleAnswerOrderRandomization}
        />
      );
    case 'free_text_question':
      return (
        <FreeTextPanel
          node={props.node}
          engine={props.engine}
        />
      );
    case 'multiple_choices_question':
      return (
        <MultipleChoicePanel
          node={props.node}
          engine={props.engine}
          lockPossibleAnswerOrderRandomization={props.lockPossibleAnswerOrderRandomization}
        />
      )
      ;
    case 'custom_content_question':
      return (
        <CustomContentOptionsPanel
          node={props.node}
          engine={props.engine}
        />
      );
    case 'slider_question':
      return (
        <SliderQuestionPanel
          node={props.node}
        />
      );
    default:
      console.debug('Unrecognized question type: ', props.node.question.type.value);
      return null;
  }
}

export default QuestionTypeOptions;
