import React from 'react';
import PropTypes from 'prop-types';
import Spinner from '../../Spinner';
import PromptSelection from './PromptSelection';
import PromptEditor from './PromptEditor';
import OutlineDisplay from './OutlineDisplay';
import ReadoutComplete from './ReadoutComplete';
import LoadingSection from './LoadingSection';

// Outline Generation Component - Initial state for admin users
const OutlineGeneration = ({
  selectedPromptVersion,
  handlePromptVersionChange,
  promptTemplates,
  promptText,
  showPromptEditor,
  setShowPromptEditor,
  onSaveEditedPrompt,
  generateOutline,
  isLoading,
  features,
}) => (
  <div className="generate-outline-section">
    <PromptSelection
      selectedPromptVersion={selectedPromptVersion}
      handlePromptVersionChange={handlePromptVersionChange}
      promptTemplates={promptTemplates}
      isLoading={isLoading}
    />

    <PromptEditor
      promptText={promptText}
      showPromptEditor={showPromptEditor}
      setShowPromptEditor={setShowPromptEditor}
      onSaveEditedPrompt={onSaveEditedPrompt}
      isLoading={isLoading}
    />

    <div className="button-container">
      <button
        className="pi-primary-button generate-outline-button"
        onClick={generateOutline}
        disabled={isLoading || (features.canSelectPrompt && !selectedPromptVersion)}
      >
        <span className="button-text">
          {isLoading ? 'GENERATING OUTLINE' : 'GENERATE OUTLINE'}
        </span>
        {isLoading ? <Spinner className="button-spinner" /> : null}
      </button>
    </div>
  </div>
);

OutlineGeneration.propTypes = {
  selectedPromptVersion: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
  handlePromptVersionChange: PropTypes.func,
  promptTemplates: PropTypes.array,
  promptText: PropTypes.string,
  showPromptEditor: PropTypes.bool,
  setShowPromptEditor: PropTypes.func,
  onSaveEditedPrompt: PropTypes.func,
  generateOutline: PropTypes.func,
  isLoading: PropTypes.bool.isRequired,
  features: PropTypes.object.isRequired,
};

const AdminFlow = ({
  state,
  promptState,
  promptActions,
  outlineState,
  outlineActions,
  actions,
  config,
}) => {
  const { outlineContent, gammaUrl, isLoading, currentJobStatus, currentJobId, completionDate } = state;
  const { promptTemplates, selectedPromptVersion, promptText, showPromptEditor } = promptState;
  const { showOutlineEditor, editedOutlineContent } = outlineState;
  const { handlePromptVersionChange, setShowPromptEditor, onSaveEditedPrompt } = promptActions;
  const { setShowOutlineEditor, setEditedOutlineContent } = outlineActions;
  const { generateOutline, setOutlineContent, setError, generateGammaPresentation, setGammaUrl, setCurrentJobId, setCurrentJobStatus, setCompletionDate } = actions;
  const { features, authenticityToken, surveyId } = config;
  
  const isGeneratingGamma = currentJobStatus === 'generating_gamma';

  // Define the four possible states explicitly
  const STATE = {
    COMPLETED: 'completed',
    OUTLINE_READY: 'outline_ready',
    LOADING: 'loading',
    INITIAL: 'initial'
  };

  // Determine current state based on props
  const getCurrentState = () => {
    if (gammaUrl) return STATE.COMPLETED;
    if (isLoading) return STATE.LOADING;
    if (outlineContent) return STATE.OUTLINE_READY;
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
            onGenerateNewOutline={() => {
              setOutlineContent('');
              setGammaUrl(null);
              setCurrentJobId(null);
              setCurrentJobStatus(null);
              setCompletionDate(null);
              setError(null);
            }}
          />
        );

      case STATE.OUTLINE_READY:
        return (
          <OutlineDisplay
            outlineContent={outlineContent}
            features={features}
            setOutlineContent={setOutlineContent}
            setError={setError}
            isLoading={isLoading}
            surveyId={surveyId}
            currentJobId={currentJobId}
            authenticityToken={authenticityToken}
            showOutlineEditor={showOutlineEditor}
            setShowOutlineEditor={setShowOutlineEditor}
            editedOutlineContent={editedOutlineContent}
            setEditedOutlineContent={setEditedOutlineContent}
            generateGammaPresentation={generateGammaPresentation}
            completionDate={completionDate}
          />
        );

      case STATE.LOADING:
        return (
          <LoadingSection message={isGeneratingGamma ? 'Creating your presentation...' : 'Generating outline...'} />
        );

      case STATE.INITIAL:
        return (
          <OutlineGeneration
            selectedPromptVersion={selectedPromptVersion}
            handlePromptVersionChange={handlePromptVersionChange}
            promptTemplates={promptTemplates}
            promptText={promptText}
            showPromptEditor={showPromptEditor}
            setShowPromptEditor={setShowPromptEditor}
            onSaveEditedPrompt={onSaveEditedPrompt}
            generateOutline={generateOutline}
            isLoading={isLoading}
            features={features}
          />
        );

      default:
        console.warn(`Unknown state: ${currentState}`);
        return (
          <OutlineGeneration
            selectedPromptVersion={selectedPromptVersion}
            handlePromptVersionChange={handlePromptVersionChange}
            promptTemplates={promptTemplates}
            promptText={promptText}
            showPromptEditor={showPromptEditor}
            setShowPromptEditor={setShowPromptEditor}
            onSaveEditedPrompt={onSaveEditedPrompt}
            generateOutline={generateOutline}
            isLoading={isLoading}
            features={features}
          />
        );
    }
  };

  return renderStateComponent();
};

AdminFlow.propTypes = {
  state: PropTypes.shape({
    outlineContent: PropTypes.string,
    gammaUrl: PropTypes.string,
    isLoading: PropTypes.bool.isRequired,
    currentJobStatus: PropTypes.string,
    currentJobId: PropTypes.number,
    completionDate: PropTypes.string,
  }).isRequired,
  promptState: PropTypes.shape({
    promptTemplates: PropTypes.array,
    selectedPromptVersion: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
    promptText: PropTypes.string,
    showPromptEditor: PropTypes.bool,
  }).isRequired,
  promptActions: PropTypes.shape({
    handlePromptVersionChange: PropTypes.func,
    setShowPromptEditor: PropTypes.func,
    onSaveEditedPrompt: PropTypes.func,
  }).isRequired,
  outlineState: PropTypes.shape({
    showOutlineEditor: PropTypes.bool,
    editedOutlineContent: PropTypes.string,
  }).isRequired,
  outlineActions: PropTypes.shape({
    setShowOutlineEditor: PropTypes.func,
    setEditedOutlineContent: PropTypes.func,
  }).isRequired,
  actions: PropTypes.shape({
    generateOutline: PropTypes.func,
    setOutlineContent: PropTypes.func.isRequired,
    setError: PropTypes.func.isRequired,
    generateGammaPresentation: PropTypes.func,
    setGammaUrl: PropTypes.func.isRequired,
    setCurrentJobId: PropTypes.func.isRequired,
    setCurrentJobStatus: PropTypes.func.isRequired,
    setCompletionDate: PropTypes.func.isRequired,
  }).isRequired,
  config: PropTypes.shape({
    features: PropTypes.object.isRequired,
    authenticityToken: PropTypes.string.isRequired,
    surveyId: PropTypes.number.isRequired,
  }).isRequired,
};

export default AdminFlow;
