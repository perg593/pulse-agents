import React from 'react';
import PropTypes from 'prop-types';

import SettingsIcon from '../../images/survey_editor/settings.svg';
import SettingsModal from './SettingsModal';

InvitationOptions.propTypes = {
  node: PropTypes.object.isRequired,
};

/**
 * The options for the invitation settings modal
 * @param { Object } props
 * @return { JSX.Element } the options panel
*/
function InvitationOptions(props) {
  const [nodeProperties, setNodeProperties] = React.useState({
    invitationButtonDisabled: props.node.invitation.invitationButtonDisabled,
  });

  const onNodePropertyChange = (newObject) => {
    setNodeProperties(
        {
          ...nodeProperties,
          ...newObject,
        },
    );

    props.node.updateInvitation(newObject);
  };

  return (
    <div className='collapsible-panel'>
      <div className='collapsible-panel-content'>
        <input
          id='hide_invitation'
          type="checkbox"
          onChange={(e) => onNodePropertyChange({invitationButtonDisabled: e.target.checked})}
          value={nodeProperties.invitationButtonDisabled}
          checked={nodeProperties.invitationButtonDisabled}
        />
        <label htmlFor='hide_invitation'>Hide button</label>
      </div>
    </div>
  );
}

InvitationSettingsModal.propTypes = {
  node: PropTypes.object,
  engine: PropTypes.object,
};

/**
 * The modal for the invitation settings
 * @param { Object } props
 * @return { JSX.Element } the modal
*/
function InvitationSettingsModal(props) {
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
      <InvitationOptions node={props.node} />
    </SettingsModal>
  );
}

export default InvitationSettingsModal;
