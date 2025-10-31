import React from 'react';
import PropTypes from 'prop-types';
import OutlineContent from './OutlineContent';

const OutlineDisplay = ({
  outlineContent, 
  features, 
  setOutlineContent, 
  setError, 
  isLoading, 
  surveyId, 
  currentJobId, 
  authenticityToken,
  showOutlineEditor,
  setShowOutlineEditor,
  editedOutlineContent,
  setEditedOutlineContent,
  generateGammaPresentation,
  completionDate
}) => (
  <div className="outline-display-section">
    <OutlineContent 
      outlineContent={outlineContent} 
      surveyId={surveyId} 
      currentJobId={currentJobId}
      canEdit={features.canEditOutlines}
      onOutlineUpdate={setOutlineContent}
      authenticityToken={authenticityToken}
      showOutlineEditor={showOutlineEditor}
      setShowOutlineEditor={setShowOutlineEditor}
      editedOutlineContent={editedOutlineContent}
      setEditedOutlineContent={setEditedOutlineContent}
      completionDate={completionDate}
    />

    {
      features.canEditOutlines ? (
        <div className="button-container">
          <button
            className="pi-primary-button generate-outline-button"
            onClick={() => generateGammaPresentation()}
            disabled={isLoading}
          >
            CREATE READOUT
          </button>
          <button
            className="inconspicuous-button"
            onClick={() => {
              setOutlineContent('');
              setError(null);
            }}
            disabled={isLoading}
          >
            Restart
          </button>
        </div>
      ) : null
    }
  </div>
);

OutlineDisplay.propTypes = {
  outlineContent: PropTypes.string.isRequired,
  features: PropTypes.object.isRequired,
  setOutlineContent: PropTypes.func.isRequired,
  setError: PropTypes.func.isRequired,
  isLoading: PropTypes.bool.isRequired,
  surveyId: PropTypes.number.isRequired,
  currentJobId: PropTypes.number,
  authenticityToken: PropTypes.string.isRequired,
  showOutlineEditor: PropTypes.bool,
  setShowOutlineEditor: PropTypes.func,
  editedOutlineContent: PropTypes.string,
  setEditedOutlineContent: PropTypes.func,
  generateGammaPresentation: PropTypes.func,
  completionDate: PropTypes.string,
};

export default OutlineDisplay;
