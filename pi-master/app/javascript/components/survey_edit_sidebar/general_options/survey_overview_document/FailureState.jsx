import React from 'react';
import PropTypes from 'prop-types';

FailureState.propTypes = {
  failureReason: PropTypes.string.isRequired,
  regenerate: PropTypes.func.isRequired,
};

/**
 * Component for showing the failure state of a survey overview document
 * @param {Object} props - see propTypes
 * @return {JSX.Element}
 */
function FailureState(props) {
  return (
    <>
      <p className="error-message">
        Failed to generate survey overview document:
      </p>
      <p className="error-message">
        {props.failureReason}
      </p>
      <button
        className="sidebar-button secondary"
        onClick={(e) => {
          props.regenerate();
        }}
      >
        TRY AGAIN
      </button>
    </>
  );
}

export default FailureState;
