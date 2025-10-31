import React from 'react';
import PropTypes from 'prop-types';

interface FooterProps {
  children: PropTypes.node.isRequired;
}

const Footer = (props: FooterProps) => {
  return (
    <div className='pi-modal-footer'>
      {props.children}
    </div>
  );
};

export default Footer;
