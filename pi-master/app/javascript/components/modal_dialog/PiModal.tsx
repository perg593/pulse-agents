import React from 'react';
import PropTypes from 'prop-types';
import classNames from 'classnames';

import ModalContext from './ModalContext';

import Header from './Header';
import Body from './Body';
import Footer from './Footer';

interface PiModalProps {
  children: PropTypes.node.isRequired;
  modalClassName: string;
  onClose: (closeEvent: Event) => void;
}

/**
 * A modal dialogue that leverages the new <dialog> element
 **/
const PiModal = React.forwardRef(function PiModal(props: PiModalProps, ref) {
  const contextRef = React.useRef(null);

  // We're using forwardRef, so we won't have a ref available right away.
  // We'll wait until we have one to set the one for our modal context
  React.useEffect(() => {
    if (ref.current) {
      contextRef.current = ref.current;

      if (props.onClose) {
        ref.current.addEventListener('close', (e) => {
          props.onClose(e);
        });
      }
    }
  }, [ref]);

  /**
   * Closes the dialog if its backdrop has been clicked.
   * @param {MouseEvent} e
   **/
  function handleClick(e: React.MouseEvent<HTMLDialogElement, MouseEvent>) {
    if (ref.current && e.target == ref.current) {
      ref.current.close();
    }
  }

  return (
    <ModalContext.Provider value={contextRef}>
      <dialog
        ref={ref}
        className={classNames('pi-modal', props.modalClassName)}
        onClick={(e) => handleClick(e)}
      >
        { props.children }
      </dialog>
    </ModalContext.Provider>
  );
});

PiModal.Header = Header;
PiModal.Body = Body;
PiModal.Footer = Footer;

export default PiModal;
