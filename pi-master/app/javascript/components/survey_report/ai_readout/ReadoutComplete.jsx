import React from 'react';
import PropTypes from 'prop-types';

import OpenInNewTabIcon from '../../../images/open_in_new.svg';

const ReadoutComplete = ({gammaUrl, features, onRetry, onGenerateNewOutline, completionDate}) => (
  <div className="readout-complete">
    <div className="success-message">
      <div className="title-with-metadata">
        <h4>✅ Your presentation is ready!</h4>
        {
          completionDate ? (
            <span className="completion-metadata">
              Generated on: <time dateTime={completionDate}>
                {new Date(completionDate).toLocaleDateString('en-US', {
                  month: '2-digit',
                  day: '2-digit',
                  year: 'numeric'
                })}
              </time>
            </span>
          ) : null
        }
      </div>
      <p>Your AI-generated presentation has been created successfully.</p>
    </div>
    
    <div className="button-container">
      <button
        className="pi-primary-button download-presentation-btn"
        onClick={() => window.open(gammaUrl, '_blank')}
      >
        <div className='labeled-icon-container'>
          <span
            className='button-icon'
            style={{
              maskImage: `url(${OpenInNewTabIcon})`,
              WebkitMaskImage: `url(${OpenInNewTabIcon})`,
            }}
          >
          </span>
          <span>OPEN PRESENTATION</span>
        </div>
      </button>
      {
        features.canGenerateOutlines ? (
          <button
            className="pi-secondary-button generate-new-outline-btn"
            onClick={onGenerateNewOutline}
          >
            Start Over
          </button>
        ) : (
          <button
            className="btn btn-secondary retry-btn"
            onClick={onRetry}
          >
            Create Another
          </button>
        )
      }
    </div>
  </div>
);

ReadoutComplete.propTypes = {
  gammaUrl: PropTypes.string.isRequired,
  features: PropTypes.object.isRequired,
  onRetry: PropTypes.func.isRequired,
  onGenerateNewOutline: PropTypes.func,
  completionDate: PropTypes.string,
};

export default ReadoutComplete;
