import React from 'react';
import PropTypes from 'prop-types';
import {toBlob} from 'html-to-image';
import SparklesIcon from '../../../../images/sparkles.svg';

CanvasScreenshot.propTypes = {
  authenticityToken: PropTypes.string.isRequired,
  isGenerating: PropTypes.bool.isRequired,
  onStepComplete: PropTypes.func.isRequired,
  surveyId: PropTypes.string.isRequired,
  surveyOverviewDocumentId: PropTypes.number,
};

/**
 * Component for capturing a screenshot of the survey editor canvas.
 * @param {Object} props - see propTypes
 * @return {JSX.Element}
 */
function CanvasScreenshot(props) {
  const {
    authenticityToken,
    isGenerating,
    onStepComplete,
    surveyId,
    surveyOverviewDocumentId,
  } = props;

  /**
   * Handle API response.
   * @param {Response} response - Fetch response
   * @return {Promise<Object>} Parsed response data
   */
  const handleResponse = (response) => {
    if (!response.ok) {
      return response.json().then((json) => {
        throw new Error(
            json.errors?.join(', ') ||
          'An error occurred. Please contact support for assistance.',
        );
      });
    }
    return response.json();
  };

  /**
   * Handle the canvas screenshot capture process.
   * @param {Event} e - Event
   */
  const handleCanvasScreenshot = (e) => {
    e.preventDefault(); // Prevent default form submission

    // Get the canvas element
    const canvas = document.querySelector('.canvas-widget');
    if (!canvas) {
      onStepComplete({
        error: 'Unable to find the survey editor canvas. Please contact support for assistance.',
      });
      return;
    }

    // Set isGenerating to true before starting the process
    onStepComplete({isGenerating: true});

    // Ensure fonts are loaded before capturing
    document.fonts.ready.then(() => {
      // Convert canvas to blob
      toBlob(canvas, {
        type: 'image/png',
        fontEmbedCSS: true,
        skipFonts: false,
      })
          .then((blob) => {
            const formData = new FormData();
            formData.append(
                'survey_overview_document[survey_editor_screenshot]',
                blob,
                'screenshot.png',
            );
            formData.append(
                'survey_overview_document[survey_id]',
                surveyId,
            );

            // If we have an existing document, update it instead of
            // creating a new one
            const url = surveyOverviewDocumentId ?
              `/admin/survey_overview_documents/${surveyOverviewDocumentId}` :
              '/admin/survey_overview_documents';
            const method = surveyOverviewDocumentId ? 'PATCH' : 'POST';

            fetch(url, {
              method: method,
              headers: {
                'X-CSRF-Token': authenticityToken,
              },
              body: formData,
            })
                .then(handleResponse)
                .then((data) => {
                  onStepComplete({
                    isGenerating: false,
                    id: data.id,
                    status: data.status,
                    successMessage: 'Step 1 completed: Screenshot captured',
                  });
                })
                .catch((err) => {
                  onStepComplete({
                    isGenerating: false,
                    error: 'Unable to save the screenshot. Please contact support for assistance.',
                  });
                });
          })
          .catch((err) => {
            onStepComplete({
              isGenerating: false,
              error: 'Unable to capture the screenshot. Please contact support for assistance.',
            });
          });
    });
  };

  return (
    <div className="step-content">
      <h3 className="step-title">Step 1: Capture Survey Flow</h3>
      <p className="step-description">
        Position the question cards to reflect the intended flow.
        The screenshot will capture exactly what is visible on screen.
      </p>
      <div className="sidebar-option-row horizontal">
        <button
          onClick={handleCanvasScreenshot}
          className="sidebar-button with-icon"
          disabled={isGenerating}
        >
          <img
            src={SparklesIcon}
            alt="Sparkles"
          />
          <span>CAPTURE SCREENSHOT</span>
        </button>
      </div>
    </div>
  );
}

export default CanvasScreenshot;
