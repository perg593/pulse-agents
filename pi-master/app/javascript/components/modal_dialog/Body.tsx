import React from 'react';
import PropTypes from 'prop-types';

interface BodyProps {
  children: PropTypes.node.isRequired;
}

const Body = (props: BodyProps) => {
  return (
    <div className='pi-modal-body'>
      {props.children}
    </div>
  );
};

export default Body;
