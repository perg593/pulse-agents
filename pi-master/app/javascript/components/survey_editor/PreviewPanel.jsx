import React from 'react';
import PropTypes from 'prop-types';

import DesktopIcon from '../../images/survey_editor/monitor.svg';
import GlobeIcon from '../../images/survey_editor/globe.svg';

PreviewPanel.propTypes = {
  surveyPreviewData: PropTypes.object.isRequired,
  showLivePreviewModal: PropTypes.func.isRequired,
};

/**
 * A wrapper component for the survey edit page's preview panel
 * @param { Object } props -- See propTypes
 * @return { JSX.Element }
 */
function PreviewPanel(props) {
  const [showPreviewModal, setShowPreviewModal] = React.useState(false);

  const showSurveyPreview = () => {
    window.PulseInsightsObject.renderSurvey(props.surveyPreviewData);
    setShowPreviewModal(true);

    window.PulseInsightsObject.onclose(() => setShowPreviewModal(false));
    window.PulseInsightsObject.oncomplete(() => setShowPreviewModal(false));
  };

  const handlePreviewModalClose = () => {
    setShowPreviewModal(false);
    window.PulseInsightsObject.survey.tearDownWidget();
  };

  const PreviewModal = () => {
    if (!showPreviewModal) {
      return null;
    }

    return (
      <div className='preview-overlay'>
        <div className='preview-overlay-header'>
          <label
            className='preview-overlay-title'
            htmlFor='close_preview_overlay_button'
          >
            Close Preview
          </label>
          <button
            id='close_preview_overlay_button'
            type='button'
            className='preview-overlay-close-button'
            onClick={handlePreviewModalClose}
          >
            ×
          </button>
        </div>
        <div className='preview-overlay-body'>
          <div id='inline_survey_target_area'></div>
        </div>
      </div>
    );
  };

  const PreviewIcon = ({icon, onClick}) => {
    return (
      <li
        className='device-preview-icon'
        onClick={onClick}
        style={{
          maskImage: `url(${icon})`,
          WebkitMaskImage: `url(${icon})`,
        }}
      />
    );
  };

  return (
    <div className='preview-options-container'>
      <PreviewModal />
      <span className='preview-header'>PREVIEW</span>
      <ul className='footer-preview-buttons-container'>
        <PreviewIcon
          icon={DesktopIcon}
          onClick={showSurveyPreview}
        />
        <PreviewIcon
          icon={GlobeIcon}
          onClick={props.showLivePreviewModal}
        />
      </ul>
    </div>
  );
}

export default PreviewPanel;
