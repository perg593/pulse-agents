import React from 'react';
import PropTypes from 'prop-types';
import Spinner from '../../Spinner';
import ReadoutDescription from './ReadoutDescription';
import ReadoutComplete from './ReadoutComplete';
import LoadingSection from './LoadingSection';

// Call to Action Component - Initial state for non-admin users
const CallToAction = ({ createReadout, isLoading }) => (
  <div className="create-readout-section">
    <p>
      Generate a professional, presentation-ready readout from your survey data
      using AI. The presentation can be viewed, edited, and shared. We recommend
      reviewing the output to ensure accuracy
    </p>

    <div className="button-container">
      <button
        className="pi-primary-button create-readout-button"
        onClick={createReadout}
        disabled={isLoading}
      >
        <span className="button-text">CREATE READOUT</span>
        {isLoading ? <Spinner className="button-spinner" /> : null}
      </button>
    </div>
  </div>
);

CallToAction.propTypes = {
  createReadout: PropTypes.func.isRequired,
  isLoading: PropTypes.bool.isRequired,
};

const NonAdminFlow = ({
  state,
  actions,
  config,
}) => {
  const { gammaUrl, isLoading, currentJobStatus, completionDate } = state;
  const { createReadout, setOutlineContent, setError } = actions;
  const { features } = config;
  
  const isGeneratingGamma = currentJobStatus === 'generating_gamma';

  // Define the three possible states explicitly
  const STATE = {
    COMPLETED: 'completed',
    LOADING: 'loading', 
    INITIAL: 'initial'
  };

  // Determine current state based on props
  const getCurrentState = () => {
    if (gammaUrl) return STATE.COMPLETED;
    if (isLoading) return STATE.LOADING;
    return STATE.INITIAL;
  };

  const currentState = getCurrentState();

  // Render the appropriate component based on state
  const renderStateComponent = () => {
    switch (currentState) {
      case STATE.COMPLETED:
        return (
          <ReadoutComplete
            gammaUrl={gammaUrl}
            features={features}
            completionDate={completionDate}
            onRetry={() => {
              setOutlineContent('');
              setError(null);
            }}
          />
        );

      case STATE.LOADING:
        return (
          <LoadingSection message={isGeneratingGamma ? 'Creating your presentation...' : 'Creating readout...'} />
        );

      case STATE.INITIAL:
        return (
          <CallToAction createReadout={createReadout} isLoading={isLoading} />
        );

      default:
        console.warn(`Unknown state: ${currentState}`);
        return (
          <CallToAction createReadout={createReadout} isLoading={isLoading} />
        );
    }
  };

  return renderStateComponent();
};

NonAdminFlow.propTypes = {
  state: PropTypes.shape({
    gammaUrl: PropTypes.string,
    isLoading: PropTypes.bool.isRequired,
    currentJobStatus: PropTypes.string,
    completionDate: PropTypes.string,
  }).isRequired,
  actions: PropTypes.shape({
    createReadout: PropTypes.func,
    setOutlineContent: PropTypes.func.isRequired,
    setError: PropTypes.func.isRequired,
  }).isRequired,
  config: PropTypes.shape({
    features: PropTypes.object.isRequired,
  }).isRequired,
};

export default NonAdminFlow;
