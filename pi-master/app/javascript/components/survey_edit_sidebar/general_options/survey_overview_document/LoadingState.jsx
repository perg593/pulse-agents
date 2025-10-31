import React from 'react';
import PropTypes from 'prop-types';
import Spinner from '../../../Spinner';

/**
 * Component for displaying the loading state of the survey overview document
 * @param {Object} props - see propTypes
 * @return {JSX.Element}
 */
function LoadingState() {
  return (
    <div className="loading-container">
      <Spinner />
      <p className="loading-message">Processing...</p>
    </div>
  );
}

export default LoadingState;
