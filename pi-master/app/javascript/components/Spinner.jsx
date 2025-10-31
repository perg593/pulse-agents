import React from 'react';
import PropTypes from 'prop-types';

const Spinner = (props) => {
  return (
    <div className={`pi-spinner ${props.className ?? ''}`}>
    </div>
  );
};

Spinner.propTypes = {
  className: PropTypes.string,
};

export default Spinner;
