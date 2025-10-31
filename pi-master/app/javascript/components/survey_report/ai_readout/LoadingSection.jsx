import React from 'react';
import PropTypes from 'prop-types';
import Spinner from '../../Spinner';

const LoadingSection = ({message}) => (
  <div className="loading-section">
    <Spinner />
    <span className='loading-message'>{message}</span>
  </div>
);

LoadingSection.propTypes = {
  message: PropTypes.string.isRequired,
};

export default LoadingSection;
