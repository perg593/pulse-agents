import React from 'react';
import PropTypes from 'prop-types';
import DeleteButton from '../../../../components/DeleteButton';
import SparklesIcon from '../../../../images/sparkles.svg';
import DebouncedInput from '../../../../components/DebouncedInput';
import AuthenticationConfig from './AuthenticationConfig';
import ViewportConfig from './ViewportConfig';

RemoteScreenshot.propTypes = {
  surveyOverviewDocument: PropTypes.shape({
    id: PropTypes.number,
    configuration: PropTypes.shape({
      target_url: PropTypes.string,
      cookie_selectors: PropTypes.arrayOf(PropTypes.string),
      viewport_config: PropTypes.object,
      authentication_config: PropTypes.object,
    }),
    isGenerating: PropTypes.bool,
  }).isRequired,
  authenticityToken: PropTypes.string.isRequired,
  onStepComplete: PropTypes.func.isRequired,
  onConfigurationChange: PropTypes.func.isRequired,
  showError: PropTypes.bool,
  failureReason: PropTypes.string,
};

/**
 * Component for capturing screenshots on the client's site.
 * @param {Object} props - see propTypes
 * @return {JSX.Element}
 */
function RemoteScreenshot(props) {
  const {
    surveyOverviewDocument,
    authenticityToken,
    onStepComplete,
    onConfigurationChange,
    showError = false,
    failureReason,
  } = props;

  const { id, configuration, isGenerating } = surveyOverviewDocument;
  const targetUrlBlank = !configuration?.target_url?.trim();
  const disabled = isGenerating || targetUrlBlank;

  /**
   * Update the target URL configuration.
   * @param {string} value - New target URL
   */
  const updateTargetUrl = (value) => {
    onConfigurationChange({
      ...configuration,
      target_url: value,
    });
  };

  /**
   * Update a cookie selector value.
   * @param {number} index - Index of the selector to update
   * @param {string} value - New selector value
   */
  const updateCookieSelector = (index, value) => {
    const newSelectors = [...configuration.cookie_selectors];
    newSelectors[index] = value;
    onConfigurationChange({
      ...configuration,
      cookie_selectors: newSelectors,
    });
  };

  /**
   * Add a new cookie selector field.
   */
  const addCookieSelector = () => {
    onConfigurationChange({
      ...configuration,
      cookie_selectors: [...configuration.cookie_selectors, ''],
    });
  };

  /**
   * Remove a cookie selector field.
   * @param {number} index - Index of the selector to remove
   */
  const removeCookieSelector = (index) => {
    onConfigurationChange({
      ...configuration,
      cookie_selectors: configuration.cookie_selectors.filter(
          (_, i) => i !== index,
      ),
    });
  };

  /**
   * Handle viewport configuration changes.
   * @param {Object} viewportConfig - New viewport configuration
   */
  const handleViewportConfigChange = (viewportConfig) => {
    onConfigurationChange({
      ...configuration,
      viewport_config: viewportConfig,
    });
  };

  /**
   * Handle authentication configuration changes.
   * @param {Object} authConfig - New authentication configuration
   */
  const handleAuthenticationChange = (authConfig) => {
    onConfigurationChange({
      ...configuration,
      authentication_config: authConfig,
    });
  };

  /**
   * Update the survey overview document configuration.
   * @param {Object} config - Configuration to send to the server
   * @return {Promise<Object>} Server response
   */
  const updateSurveyOverviewDocument = (config) => {
    return fetch(`/admin/survey_overview_documents/${id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': authenticityToken,
      },
      body: JSON.stringify({
        survey_overview_document: {
          client_site_configuration: config,
        },
      }),
    }).then(handleResponse);
  };

  /**
   * Start the screenshot capture process.
   * @return {Promise<Object>} Server response
   */
  const startScreenshotCapture = () => {
    return fetch(`/admin/survey_overview_documents/${id}/capture_screenshots`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': authenticityToken,
      },
    }).then(handleResponse);
  };

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
            'An error occurred while processing your request',
        );
      });
    }
    return response.json();
  };

  /**
   * Handle the remote screenshot capture process.
   * @param {Event} e - Event
   */
  const handleRemoteScreenshot = (e) => {
    e.preventDefault(); // Prevent default form submission

    if (targetUrlBlank) {
      onStepComplete({error: 'Please enter a target URL'});
      return;
    }

    // Clear any previous error state and set isGenerating to true
    onStepComplete({
      isGenerating: true,
      error: null,
      failure_reason: null,
    });

    // Only send non-empty cookie selectors
    const configToSend = {
      ...configuration,
      cookie_selectors: (configuration.cookie_selectors || []).filter(
          (selector) => selector.trim(),
      ),
    };

    updateSurveyOverviewDocument(configToSend)
        .then(startScreenshotCapture)
        .then((data) => {
          // Start polling for status updates
          const pollInterval = setInterval(() => {
            fetch(`/admin/survey_overview_documents/${id}`, {
              headers: {
                'X-CSRF-Token': authenticityToken,
              },
            })
                .then((response) => response.json())
                .then((data) => {
                  if (data.status === 'completed' || data.status === 'failed') {
                    clearInterval(pollInterval);
                    onStepComplete({
                      isGenerating: false,
                      status: data.status,
                      error: data.status === 'failed' ? 'System error occurred' : null,
                      failure_reason: data.failure_reason || data.error,
                      googlePresentationUrl: data.google_presentation_url,
                    });
                  } else if (data.status === 'generating_slides') {
                    // Screenshots are complete, update message but keep polling
                    // Clear any previous failure_reason since we succeeded
                    onStepComplete({
                      isGenerating: true,
                      status: data.status,
                      failure_reason: null,
                      successMessage: 'Screenshots captured successfully. Generating document...',
                    });
                  } else if (data.status === 'capturing_remote_screenshots' && data.failure_reason) {
                    // Screenshot capture failed but user can retry - stop polling and show error
                    clearInterval(pollInterval);
                    onStepComplete({
                      isGenerating: false,
                      status: data.status,
                      failure_reason: data.failure_reason,
                    });
                  } else if (data.status === 'capturing_remote_screenshots' && !data.failure_reason) {
                    // Screenshot capture is in progress, no failure - clear any previous failure_reason
                    onStepComplete({
                      isGenerating: true,
                      status: data.status,
                      failure_reason: null,
                    });
                  }
                })
                .catch((error) => {
                  clearInterval(pollInterval);
                  onStepComplete({
                    isGenerating: false,
                    error: 'Error checking status',
                    failure_reason: error.message || 'Network error while checking status',
                  });
                });
          }, 2000); // Poll every 2 seconds
        })
        .catch((err) => {
          onStepComplete({
            isGenerating: false,
            error: 'Unable to start screenshot capture. Please check the URL and try again.',
            failure_reason: err.message || 'Failed to initiate screenshot capture',
          });
        });
  };

  /**
   * Render a cookie selector row.
   * @param {Object} props - Component props
   * @param {number} props.index - Index of the selector
   * @return {JSX.Element}
   */
  const CookieSelectorRow = ({index}) => {
    return (
      <div className="sidebar-option-row horizontal">
        <DebouncedInput
          className="url-field"
          value={configuration.cookie_selectors[index]}
          onChange={(value) => updateCookieSelector(index, value)}
          placeholder=".cookie-banner, #cookie-notice"
        />
        <DeleteButton
          onClick={() => removeCookieSelector(index)}
        />
      </div>
    );
  };

  return (
    <div className="step-content">
      <h3 className="step-title">Step 2: Screenshot Survey On-Site</h3>
      <p className="step-description">
        Screenshots of the survey will be captured on the site below,
        shown on both desktop and mobile views.
      </p>

      {
        showError ? (
          <div className="error-section">
            <p className="error-message">
              Failed to capture screenshots:
            </p>
            <p className="error-message">
              {
                failureReason || 'An error occurred during screenshot capture. Please check your URL and cookie selectors, then try again.'
              }
            </p>
          </div>
        ) : null
      }

      <div className="survey-overview-document-form">
        <div className="form-group">
          <label htmlFor="target_url">URL</label>
          <div className="controls">
            <DebouncedInput
              type="text"
              id="target_url"
              value={configuration.target_url}
              onChange={updateTargetUrl}
              placeholder="https://example.com"
              className="form-control"
            />
          </div>
        </div>

        <div className="form-group">
          <label>Cookie Selector(s) (Optional)</label>
          <p className="hint">
            Add CSS selector(s) for any elements that may block the survey.
          </p>
          <div className="controls">
            {configuration.cookie_selectors.map((selector, index) => (
              <CookieSelectorRow key={index} index={index} />
            ))}
            <input
              type="button"
              className="sidebar-button new-trigger-button"
              onClick={addCookieSelector}
              value="ADD NEW"
            />
          </div>
        </div>

        <ViewportConfig
          viewportConfig={configuration.viewport_config}
          onViewportConfigChange={handleViewportConfigChange}
        />

        <AuthenticationConfig
          authentication={configuration.authentication_config}
          onAuthenticationChange={handleAuthenticationChange}
        />
      </div>

      <div className="sidebar-option-row horizontal">
        <button
          onClick={handleRemoteScreenshot}
          className="sidebar-button with-icon"
          disabled={disabled}
          title={targetUrlBlank ? 'Please enter a target URL' : (showError ? 'Retry with corrected values' : '')}
        >
          <img
            src={SparklesIcon}
            alt="Sparkles"
          />
          <span>{showError ? 'RETRY CAPTURE' : 'CAPTURE SCREENSHOTS'}</span>
        </button>
      </div>
    </div>
  );
}

export default RemoteScreenshot;
