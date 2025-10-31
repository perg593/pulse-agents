import React, { useContext } from 'react';
import PropTypes from 'prop-types';
import CollapsiblePanel from '../../CollapsiblePanel';
import CanvasScreenshot from './survey_overview_document/CanvasScreenshot';
import RemoteScreenshot from './survey_overview_document/RemoteScreenshot';
import SuccessState from './survey_overview_document/SuccessState';
import FailureState from './survey_overview_document/FailureState';
import LoadingState from './survey_overview_document/LoadingState';
import DisabledFeaturesContext from '../../survey_editor/DisabledFeaturesContext';

SurveyOverviewDocument.propTypes = {
  surveyId: PropTypes.number.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  authenticityToken: PropTypes.string.isRequired,
  surveyOverviewDocument: PropTypes.shape({
    id: PropTypes.number,
    status: PropTypes.string,
    isGenerating: PropTypes.bool,
    error: PropTypes.string,
    failure_reason: PropTypes.string,
    googlePresentationUrl: PropTypes.string,
    configuration: PropTypes.shape({
      target_url: PropTypes.string,
      cookie_selectors: PropTypes.arrayOf(PropTypes.string),
      viewport_config: PropTypes.object,
      authentication_config: PropTypes.object,
    }),
  }).isRequired,
  updateFunction: PropTypes.func.isRequired,
};

/**
 * Main component for managing the survey overview document generation process
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function SurveyOverviewDocument(props) {
  const {surveyOverviewDocument, updateFunction} = props;
  const {isGenerating, error} = surveyOverviewDocument;
  const { surveyOverviewDocument: isDisabled } = useContext(DisabledFeaturesContext);

  // Don't render anything if the feature is disabled
  if (isDisabled) {
    return null;
  }

  /**
   * Handle step completion
   * @param {object} updates - Updates to apply after step completion
   */
  const handleStepComplete = (updates) => {
    updateFunction({
      surveyOverviewDocument: {
        ...surveyOverviewDocument,
        ...updates,
      },
    });
  };

  /**
   * Handle configuration changes
   * @param {object} newConfiguration - New configuration object
   */
  const handleConfigurationChange = (newConfiguration) => {
    updateFunction({
      surveyOverviewDocument: {
        ...surveyOverviewDocument,
        configuration: newConfiguration,
      },
    });
  };

  /**
   * Handle creation of a new survey overview document
   */
  const handleNewDocument = () => {
    fetch('/admin/survey_overview_documents', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': props.authenticityToken,
      },
      body: JSON.stringify({
        survey_overview_document: {
          survey_id: props.surveyId,
        },
      }),
    })
        .then((response) => {
          if (!response.ok) {
            throw new Error('Failed to create new survey overview document');
          }
          return response.json();
        })
        .then((data) => {
          updateFunction({
            surveyOverviewDocument: {
              id: data.id,
              status: 'pending',
              isGenerating: false,
              error: null,
              configuration: {
                target_url: '',
                cookie_selectors: [],
              },
            },
          });
        })
        .catch((error) => {
          updateFunction({
            surveyOverviewDocument: {
              ...surveyOverviewDocument,
              error: error.message,
            },
          });
        });
  };

  /**
   * Render the appropriate content based on the current state
   * @return {JSX.Element}
   */
  function renderContent() {
    if (isGenerating) {
      return <LoadingState />;
    }

    // Don't show just the error message if the status is 'failed' or 'capturing_remote_screenshots'
    // we want to show the appropriate components with error handling
    if (error && !['failed', 'capturing_remote_screenshots'].includes(surveyOverviewDocument.status)) {
      return <p className="error-message">{error}</p>;
    }

    // Initial state - no survey overview document created yet
    if (!surveyOverviewDocument.id) {
      return (
        <CanvasScreenshot
          surveyId={props.surveyId}
          authenticityToken={props.authenticityToken}
          isGenerating={isGenerating}
          onStepComplete={handleStepComplete}
        />
      );
    }

    // Handle different states based on status
    switch (surveyOverviewDocument.status) {
      case 'pending':
        return (
          <CanvasScreenshot
            surveyId={props.surveyId}
            authenticityToken={props.authenticityToken}
            isGenerating={isGenerating}
            onStepComplete={handleStepComplete}
            surveyOverviewDocumentId={surveyOverviewDocument.id}
          />
        );
      case 'capturing_remote_screenshots':
        // Show form with error if there's a failure reason, otherwise show normal form
        return (
          <RemoteScreenshot
            surveyOverviewDocument={surveyOverviewDocument}
            authenticityToken={props.authenticityToken}
            onStepComplete={handleStepComplete}
            onConfigurationChange={handleConfigurationChange}
            showError={!!surveyOverviewDocument.failure_reason}
            failureReason={surveyOverviewDocument.failure_reason}
          />
        );
      case 'generating_slides':
        return <LoadingState />;
      case 'completed':
        return (
          <SuccessState
            googlePresentationUrl={surveyOverviewDocument.googlePresentationUrl}
            regenerate={handleNewDocument}
          />
        );
      case 'failed':
        // Only system errors that require developer intervention
        return (
          <div>
            <div className="error-section">
              <p className="error-message">
                System Error:
              </p>
              <p className="error-message">
                {surveyOverviewDocument.failure_reason || 'An unexpected error occurred. Please contact support.'}
              </p>
            </div>
            <div className="button-group">
              <button
                className="sidebar-button secondary"
                onClick={handleNewDocument}
              >
                TRY AGAIN
              </button>
            </div>
          </div>
        );
      default:
        return null;
    }
  }

  return (
    <CollapsiblePanel
      panelTitle='Survey Overview Document'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
    >
      <div className="survey-overview-document-panel">
        {renderContent()}
      </div>
    </CollapsiblePanel>
  );
}

export default SurveyOverviewDocument;
