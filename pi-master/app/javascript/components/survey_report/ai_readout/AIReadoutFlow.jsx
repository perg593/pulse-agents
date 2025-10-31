import React from 'react';
import PropTypes from 'prop-types';
import AdminFlow from './AdminFlow';
import NonAdminFlow from './NonAdminFlow';

// Main AIReadoutFlow Component
const AIReadoutFlow = ({
  outlineContent,
  gammaUrl,
  isLoading,
  currentJobStatus,
  currentJobId,
  completionDate,
  promptTemplates,
  selectedPromptVersion,
  handlePromptVersionChange,
  promptText,
  showPromptEditor,
  setShowPromptEditor,
  onSaveEditedPrompt,
  showOutlineEditor,
  setShowOutlineEditor,
  editedOutlineContent,
  setEditedOutlineContent,
  generateOutline,
  createReadout,
  setOutlineContent,
  generateGammaPresentation,
  setError,
  setGammaUrl,
  setCurrentJobId,
  setCurrentJobStatus,
  setCompletionDate,
  features,
  authenticityToken,
  surveyId,
}) => {
  // Group related props into logical state objects
  const state = {
    outlineContent,
    gammaUrl,
    isLoading,
    currentJobStatus,
    currentJobId,
    completionDate,
  };

  const promptState = {
    promptTemplates,
    selectedPromptVersion,
    promptText,
    showPromptEditor,
  };

  const outlineState = {
    showOutlineEditor,
    editedOutlineContent,
  };

  const promptActions = {
    handlePromptVersionChange,
    setShowPromptEditor,
    onSaveEditedPrompt,
  };

  const outlineActions = {
    setShowOutlineEditor,
    setEditedOutlineContent,
  };

  const actions = {
    generateOutline,
    createReadout,
    setOutlineContent,
    setError,
    generateGammaPresentation,
    setGammaUrl,
    setCurrentJobId,
    setCurrentJobStatus,
    setCompletionDate,
  };

  const config = {
    features,
    authenticityToken,
    surveyId,
  };

  // Determine if user is admin based on features
  const isAdmin = features.canGenerateOutlines || features.canEditOutlines || features.canSelectPrompt || features.canEditPrompts;

  if (isAdmin) {
    return (
      <AdminFlow
        state={state}
        promptState={promptState}
        promptActions={promptActions}
        outlineState={outlineState}
        outlineActions={outlineActions}
        actions={actions}
        config={config}
      />
    );
  }

  return (
    <NonAdminFlow
      state={state}
      actions={actions}
      config={config}
    />
  );
};

AIReadoutFlow.propTypes = {
  outlineContent: PropTypes.string,
  gammaUrl: PropTypes.string,
  isLoading: PropTypes.bool.isRequired,
  currentJobStatus: PropTypes.string,
  currentJobId: PropTypes.number,
  completionDate: PropTypes.string,
  promptTemplates: PropTypes.array,
  selectedPromptVersion: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
  handlePromptVersionChange: PropTypes.func,
  promptText: PropTypes.string,
  showPromptEditor: PropTypes.bool,
  setShowPromptEditor: PropTypes.func,
  onSaveEditedPrompt: PropTypes.func,
  showOutlineEditor: PropTypes.bool,
  setShowOutlineEditor: PropTypes.func,
  editedOutlineContent: PropTypes.string,
  setEditedOutlineContent: PropTypes.func,
  generateOutline: PropTypes.func,
  createReadout: PropTypes.func,
  setOutlineContent: PropTypes.func.isRequired,
  generateGammaPresentation: PropTypes.func,
  setError: PropTypes.func.isRequired,
  setGammaUrl: PropTypes.func.isRequired,
  setCurrentJobId: PropTypes.func.isRequired,
  setCurrentJobStatus: PropTypes.func.isRequired,
  setCompletionDate: PropTypes.func.isRequired,
  features: PropTypes.object.isRequired,
  authenticityToken: PropTypes.string.isRequired,
  surveyId: PropTypes.number.isRequired,
};

export default AIReadoutFlow;