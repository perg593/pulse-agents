import React from 'react';
import PropTypes from 'prop-types';

const OutlineContent = ({
  outlineContent, 
  surveyId, 
  currentJobId, 
  canEdit = false, 
  onOutlineUpdate, 
  authenticityToken,
  showOutlineEditor,
  setShowOutlineEditor,
  editedOutlineContent,
  setEditedOutlineContent,
  completionDate
}) => {
  const handleEditToggle = () => {
    if (!showOutlineEditor) {
      setEditedOutlineContent(outlineContent);
    }
    setShowOutlineEditor(!showOutlineEditor);
  };

  return (
    <div className="outline-content">
      <div className="outline-header">
        <div className="title-with-metadata">
          <h4>AI Generated Outline</h4>
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
        {
          canEdit ? (
            <button
              type="button"
              className="inconspicuous-button"
              onClick={handleEditToggle}
            >
              {showOutlineEditor ? 'Hide Editor' : 'Edit Outline'}
            </button>
          ) : null
        }
      </div>

      {
        showOutlineEditor ? (
          <textarea
            className="editor"
            value={editedOutlineContent || outlineContent}
            onChange={(e) => setEditedOutlineContent(e.target.value)}
            rows={20}
            placeholder="Enter your outline here..."
          />
        ) : (
          <pre className="preview-container">
            {outlineContent || 'No outline generated'}
          </pre>
        )
      }
    </div>
  );
};

OutlineContent.propTypes = {
  outlineContent: PropTypes.string.isRequired,
  surveyId: PropTypes.number.isRequired,
  currentJobId: PropTypes.number,
  canEdit: PropTypes.bool,
  onOutlineUpdate: PropTypes.func,
  authenticityToken: PropTypes.string.isRequired,
  showOutlineEditor: PropTypes.bool,
  setShowOutlineEditor: PropTypes.func,
  editedOutlineContent: PropTypes.string,
  setEditedOutlineContent: PropTypes.func,
  completionDate: PropTypes.string,
};

export default OutlineContent;
