import React from 'react';
import PropTypes from 'prop-types';

import SettingsIcon from '../../images/survey_editor/settings.svg';
import SettingsModal from '../survey_editor/SettingsModal';

import QuestionTypeOptions from './QuestionTypeOptions';

QuestionSettingsModal.propTypes = {
  node: PropTypes.object.isRequired,
  engine: PropTypes.object,
  lockPossibleAnswerOrderRandomization: PropTypes.bool.isRequired,
};
/**
 * The top-level wrapper for question settings
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function QuestionSettingsModal(props) {
  const modalTrigger = () => {
    return (
      <div>
        <img src={SettingsIcon}/>
        <span>SETTINGS</span>
      </div>
    );
  };

  return (
    <SettingsModal
      engine={props.engine}
      modalTrigger={modalTrigger()}
      node={props.node}
    >
      <QuestionTypeOptions
        node={props.node}
        engine={props.engine}
        lockPossibleAnswerOrderRandomization={props.lockPossibleAnswerOrderRandomization}
      />
    </SettingsModal>
  );
}

export default QuestionSettingsModal;
