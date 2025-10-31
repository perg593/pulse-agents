import React from 'react';
import PropTypes from 'prop-types';

import PiModal from '../modal_dialog/PiModal';

SettingsModal.propTypes = {
  engine: PropTypes.object.isRequired,
  children: PropTypes.node.isRequired,
  modalTrigger: PropTypes.node,
  node: PropTypes.object.isRequired,
};

/**
 * A modal dialog for node settings
 * @param { Object } props
 * @return { JSX.Element } the settings modal
*/
function SettingsModal(props) {
  const dialogRef = React.useRef(null);

  const openDialog = () => {
    if (dialogRef.current) {
      dialogRef.current.showModal();
    }
  };

  // Really want to be sure that any changes make it to the DOM, which
  // happens when the corresponding widget is (re)rendered
  const onClose = (e) => {
    props.node.makeDirty();
    props.node.setSelected(false);
    props.engine.repaintCanvas();
  };

  return (
    <>
      <a href='#' onClick={openDialog}>
        {props.modalTrigger}
      </a>

      <PiModal
        ref={dialogRef}
        modalClassName='survey-editor-modal'
        onClose={onClose}
      >
        <PiModal.Header
          title='Settings'
          titleClassName='settings-modal-title'
        />

        <PiModal.Body>
          {props.children}
        </PiModal.Body>
      </PiModal>
    </>
  );
}

export default SettingsModal;
