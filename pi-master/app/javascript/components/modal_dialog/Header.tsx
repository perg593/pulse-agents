import React from 'react';
import PropTypes from 'prop-types';
import classNames from 'classnames';

import ModalContext from './ModalContext';

interface HeaderProps {
  title: PropTypes.string;
  titleClassName: PropTypes.string;
  children: PropTypes.node;
}

const Header = (props: HeaderProps) => {
  const ref = React.useContext(ModalContext);

  return (
    <div className='pi-modal-header'>
      {
        props.title ?
          <h1 className={classNames(props.titleClassName)}>
            {props.title}
          </h1> : props.children
      }
      <button
        className='pi-modal-close-button'
        type='button'
        onClick={() => ref.current.close()}
      >
        ×
      </button>
    </div>
  );
};

export default Header;
