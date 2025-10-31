import React from 'react';
import PropTypes from 'prop-types';

SuccessState.propTypes = {
  googlePresentationUrl: PropTypes.string.isRequired,
  regenerate: PropTypes.func.isRequired,
};

/**
 * Component for showing the successful completion state of
 * a survey overview document
 * @param {Object} props - see propTypes
 * @return {JSX.Element}
 */
function SuccessState(props) {
  const handleRegenerate = (e) => {
    e.preventDefault();

    const confirmationMessage = 'Are you sure you want to generate a new survey overview document? You won\'t be able to access the current one after this.';

    if (window.confirm(confirmationMessage)) {
      props.regenerate();
    }
  };

  return (
    <>
      <p className="success-message">
        Document Complete
      </p>
      <div className="button-group">
        <a
          href={props.googlePresentationUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="link"
        >
          View Overview Document
        </a>
        <button
          className="sidebar-button secondary"
          onClick={handleRegenerate}
        >
          GENERATE NEW
        </button>
      </div>
    </>
  );
}

export default SuccessState;
