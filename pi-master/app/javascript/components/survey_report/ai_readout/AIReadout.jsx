import React, {useState, useEffect} from 'react';
import PropTypes from 'prop-types';
import CollapsiblePanel from '../../CollapsiblePanel';
import AIReadoutFlow from './AIReadoutFlow';

const AIReadout = (props) => {
  const [isLoading, setIsLoading] = useState(false);
  const [outlineContent, setOutlineContent] = useState(props.currentAiOutlineJob?.outline_content || '');
  const [gammaUrl, setGammaUrl] = useState(props.currentAiOutlineJob?.gamma_url || null);
  const [currentJobId, setCurrentJobId] = useState(props.currentAiOutlineJob?.id || null);
  const [currentJobStatus, setCurrentJobStatus] = useState(props.currentAiOutlineJob?.status || null);
  const [completionDate, setCompletionDate] = useState(props.currentAiOutlineJob?.completion_date || null);

  const [error, setError] = useState(null);

  const [showPromptEditor, setShowPromptEditor] = useState(false);
  const [savedPromptText, setSavedPromptText] = useState('');
  const [showOutlineEditor, setShowOutlineEditor] = useState(false);
  const [editedOutlineContent, setEditedOutlineContent] = useState('');

  // Helper function to determine if Gamma is being generated
  const isGeneratingGamma = currentJobStatus === 'generating_gamma';

  useEffect(() => {
    if (props.aiReadoutFeatures.canSelectPrompt && props.initialPromptVersion && !props.selectedPromptVersion) {
      // Set initial prompt version if not already set
      props.setSelectedPromptVersion(props.initialPromptVersion);
    }
  }, [props.aiReadoutFeatures.canSelectPrompt, props.initialPromptVersion, props.selectedPromptVersion]);

  // Resume polling for active jobs on page load
  useEffect(() => {
    if (props.currentAiOutlineJob) {
      const job = props.currentAiOutlineJob;
      
      // Resume polling for outline generation if still in progress
      if (job.status === 'generating_outline') {
        setIsLoading(true);
        // Use appropriate polling function based on user type
        if (props.aiReadoutFeatures.canGenerateOutlines) {
          pollJobStatus(job.id);
        } else {
          pollJobStatusAndGenerateGamma(job.id);
        }
      }
      
      // Resume polling for Gamma generation if still in progress
      if (job.gamma_generation_id && job.status === 'generating_gamma') {
        pollGammaStatus(job.gamma_generation_id);
      }
    }
  }, [props.currentAiOutlineJob]);

  const generateOutline = async () => {
    setIsLoading(true);
    setError(null);
    setGammaUrl(null);
    setCurrentJobId(null);
    setCurrentJobStatus(null);
    setOutlineContent('');

    try {
      const response = await fetch(getJobCreationUrl(), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': props.authenticityToken,
        },
        body: JSON.stringify({
          prompt_template_id: props.selectedPromptVersion,
          prompt_text: promptText,
        }),
      });

      const data = await response.json();

      if (response.ok) {
        setCurrentJobId(data.id);
        // Poll for job completion
        pollJobStatus(data.id);
      } else {
        throw new Error(data.error || 'Failed to generate outline');
      }
    } catch (error) {
      setError(error.message);
      setIsLoading(false);
    }
  };

  // Shared URL builders
  const getJobStatusUrl = (jobId) => `/surveys/${props.surveyId}/ai_outline_jobs/${jobId}`;
  const getJobCreationUrl = () => {
    const searchParams = new URLSearchParams(window.location.search).toString();
    return `/surveys/${props.surveyId}/ai_outline_jobs?${searchParams}`;
  };

  // Generic polling function for job status
  const pollJobStatusGeneric = async (jobId, onCompleted, onTimeout, onFailure, onError) => {
    const maxAttempts = 60; // 5 minutes with 5-second intervals
    let attempts = 0;

    const poll = async () => {
      try {
        const response = await fetch(getJobStatusUrl(jobId));
        const data = await response.json();

        if (data.status === 'outline_completed') {
          setOutlineContent(data.outline_content);
          setCurrentJobStatus(data.status);
          onCompleted(data, jobId);
        } else if (data.status === 'generating_outline' || data.status === 'pending') {
          attempts++;
          if (attempts < maxAttempts) {
            setTimeout(poll, 5000);
          } else {
            onTimeout();
          }
        } else {
          onFailure(data.status);
        }
      } catch (error) {
        onError(error);
      }
    };

    poll();
  };

  const pollJobStatus = async (jobId) => {
    pollJobStatusGeneric(
      jobId,
      () => setIsLoading(false), // onCompleted: just stop loading
      () => { // onTimeout
        setError('Outline generation timed out. Please try again.');
        setIsLoading(false);
      },
      (status) => { // onFailure
        setError('Outline generation failed. Please try again.');
        setIsLoading(false);
      },
      (error) => { // onError
        setError('Failed to check job status. Please try again.');
        setIsLoading(false);
      }
    );
  };

  const createReadout = async () => {
    setIsLoading(true);
    setError(null);
    setGammaUrl(null);
    setCurrentJobStatus(null);

    try {
      const response = await fetch(getJobCreationUrl(), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': props.authenticityToken,
        },
        body: JSON.stringify({
          use_default_prompt: true,
        }),
      });

      const data = await response.json();

      if (response.ok) {
        setCurrentJobId(data.id);
        // Poll for job completion, then automatically generate Gamma for regular users
        pollJobStatusAndGenerateGamma(data.id);
      } else {
        throw new Error(data.error || 'Failed to create readout');
      }
    } catch (error) {
      setError(error.message);
      setIsLoading(false);
    }
  };

  // Poll job status and then generate Gamma for regular users
  const pollJobStatusAndGenerateGamma = async (jobId) => {
    pollJobStatusGeneric(
      jobId,
      (data, jobId) => {
        // onCompleted: generate Gamma for regular users, or just stop loading for admins
        if (!props.aiReadoutFeatures.canGenerateOutlines) {
          generateGammaPresentation(data.outline_content, jobId);
        } else {
          setIsLoading(false);
        }
      },
      () => { // onTimeout
        setError('Readout generation timed out. Please try again.');
        setIsLoading(false);
      },
      (status) => { // onFailure
        setError('Readout generation failed. Please try again.');
        setIsLoading(false);
      },
      (error) => { // onError
        setError('Failed to check job status. Please try again.');
        setIsLoading(false);
      }
    );
  };

  // New function to generate Gamma presentation
  const generateGammaPresentation = async (content, jobId = currentJobId) => {
    setIsLoading(true);
    setCurrentJobStatus('generating_gamma');
    setError(null);

    // Use computed outline content (edited version if available)
    const contentToUse = content || computedOutlineContent;

    try {
      const response = await fetch(`/surveys/${props.surveyId}/ai_outline_jobs/generate_gamma_presentation`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': props.authenticityToken,
        },
        body: JSON.stringify({
          job_id: jobId,
          outline_content: contentToUse,
          authenticity_token: props.authenticityToken
        }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        // Start polling for Gamma completion
        pollGammaStatus(data.generation_id);
      } else {
        setError(data.error || 'Failed to start presentation generation');
        setCurrentJobStatus('failed');
        setIsLoading(false);
      }
    } catch (err) {
      setError('An error occurred while starting the presentation generation');
      setCurrentJobStatus('failed');
      setIsLoading(false);
    }
  };

  // New function to poll Gamma status
  const pollGammaStatus = (generationId) => {
    const interval = setInterval(async () => {
      try {
        const response = await fetch(`/surveys/${props.surveyId}/ai_outline_jobs/check_gamma_presentation_status?generation_id=${generationId}&authenticity_token=${props.authenticityToken}`, {
          method: 'GET'
        });

        const data = await response.json();

        if (response.ok && data.success) {
          if (data.status === 'completed' && data.gamma_url) {
            setGammaUrl(data.gamma_url);
            setCurrentJobStatus('completed');
            setIsLoading(false);
            clearInterval(interval);
          } else if (data.status === 'failed') {
            setError('Presentation generation failed');
            setCurrentJobStatus('failed');
            setIsLoading(false);
            clearInterval(interval);
          }
        } else {
          setError(data.error || 'Failed to check presentation status');
          setCurrentJobStatus('failed');
          setIsLoading(false);
          clearInterval(interval);
        }
      } catch (err) {
        setError('An error occurred while checking presentation status');
        setCurrentJobStatus('failed');
        setIsLoading(false);
        clearInterval(interval);
      }
    }, 5000);

    // Timeout after 5 minutes
    setTimeout(() => {
      clearInterval(interval);
      if (isGeneratingGamma) {
        setError('Presentation generation timed out');
        setIsGeneratingGamma(false);
        setIsLoading(false);
      }
    }, 300000);
  };

  const retryGeneration = () => {
    setError(null);
    setGammaUrl(null);
    setCurrentJobId(null);

    if (props.aiReadoutFeatures.canGenerateOutlines && outlineContent) {
      generateOutline();
    } else {
      createReadout();
    }
  };

  const handlePromptVersionChange = (versionId) => {
    props.setSelectedPromptVersion(versionId);
  };

  const handleSaveEditedPrompt = (text) => {
    setSavedPromptText(text);
  };

  // Computed prompt text based on selected version
  const promptText = (() => {
    // Use saved prompt text if available
    if (savedPromptText) {
      return savedPromptText;
    }

    if (props.aiReadoutFeatures.canSelectPrompt && props.selectedPromptVersion) {
      const selectedTemplate = props.promptTemplates.find((template) => {
        return template.id === parseInt(props.selectedPromptVersion, 10);
      });

      if (selectedTemplate) {
        return selectedTemplate.content;
      }
    }

    return props.initialPromptText || '';
  })();

  // Computed outline content based on editing state
  const computedOutlineContent = (() => {
    if (showOutlineEditor && editedOutlineContent) {
      return editedOutlineContent;
    }
    return outlineContent;
  })();

  return (
    <CollapsiblePanel
      panelTitle="AI Readout"
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
    >
      <div className="ai-readout">
        {
          error ? (
            <div className="error-message">
              <p>{error}</p>
              <button
                className="retry-button"
                onClick={retryGeneration}
                disabled={isLoading}
              >
                Retry
              </button>
            </div>
          ) : null
        }

        <AIReadoutFlow
          outlineContent={computedOutlineContent}
          gammaUrl={gammaUrl}
          isLoading={isLoading}
          currentJobStatus={currentJobStatus}
          currentJobId={currentJobId}
          completionDate={completionDate}
          promptTemplates={props.promptTemplates}
          selectedPromptVersion={props.selectedPromptVersion}
          handlePromptVersionChange={handlePromptVersionChange}
          promptText={promptText}
          showPromptEditor={showPromptEditor}
          setShowPromptEditor={setShowPromptEditor}
          onSaveEditedPrompt={handleSaveEditedPrompt}
          showOutlineEditor={showOutlineEditor}
          setShowOutlineEditor={setShowOutlineEditor}
          editedOutlineContent={editedOutlineContent}
          setEditedOutlineContent={setEditedOutlineContent}
          generateOutline={generateOutline}
          createReadout={createReadout}
          setOutlineContent={setOutlineContent}
          generateGammaPresentation={generateGammaPresentation}
          setError={setError}
          setGammaUrl={setGammaUrl}
          setCurrentJobId={setCurrentJobId}
          setCurrentJobStatus={setCurrentJobStatus}
          setCompletionDate={setCompletionDate}
          features={props.aiReadoutFeatures}
          authenticityToken={props.authenticityToken}
          surveyId={props.surveyId}
        />

      </div>
    </CollapsiblePanel>
  );
};

AIReadout.propTypes = {
  surveyId: PropTypes.number.isRequired,
  authenticityToken: PropTypes.string.isRequired,
  aiReadoutFeatures: PropTypes.object.isRequired,
  answerCount: PropTypes.number.isRequired,
  panelExpansionSettings: PropTypes.object,
  updatePanelExpansionSettings: PropTypes.func,
  selectedPromptVersion: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
  setSelectedPromptVersion: PropTypes.func.isRequired,
  promptTemplates: PropTypes.array,
  initialPromptVersion: PropTypes.number,
  initialPromptText: PropTypes.string,
  currentAiOutlineJob: PropTypes.object,
};

export default AIReadout;