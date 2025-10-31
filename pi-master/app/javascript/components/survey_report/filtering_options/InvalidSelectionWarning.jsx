import React from 'react';
import PropTypes from 'prop-types';

/**
 * A simple message explaining an invalid selection
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function InvalidSelectionWarning(props) {
  if (props.valid) {
    return null;
  } else {
    return <h4 className='invalid-selection-warning'>{props.message}</h4>;
  }
}

InvalidSelectionWarning.propTypes = {
  valid: PropTypes.bool.isRequired,
  message: PropTypes.string.isRequired,
};

export default InvalidSelectionWarning;
