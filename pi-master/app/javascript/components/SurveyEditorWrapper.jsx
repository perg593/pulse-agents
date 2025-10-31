import React from 'react';
import PropTypes from 'prop-types';

import DisabledFeaturesContext from './survey_editor/DisabledFeaturesContext';
import {ErrorBoundary} from 'react-error-boundary';

import SurveyEditor from './survey_editor/SurveyEditor';

import ErrorFallback from './ErrorFallback';

SurveyEditorWrapper.propTypes = {
  // See SurveyEditor
  surveyId: PropTypes.number.isRequired,
  questionData: PropTypes.array.isRequired,
  surveyData: PropTypes.object.isRequired,
  disableStructuralChanges: PropTypes.bool.isRequired,
  readOnly: PropTypes.bool,
  isAdmin: PropTypes.bool.isRequired,

  // See PreviewPanel
  surveyPreviewData: PropTypes.object.isRequired,
  authenticityToken: PropTypes.string.isRequired,
  livePreviewUrl: PropTypes.string,

  // See SurveySubNav
  subnavLinks: PropTypes.array.isRequired,

  // See SurveySettingsSiderbar
  openTabName: PropTypes.string,
  surveyGeneralOptions: PropTypes.object.isRequired,
  surveyTargetingOptions: PropTypes.object.isRequired,
  surveyFormattingOptions: PropTypes.object.isRequired,
  surveyTags: PropTypes.array,
  htmlAttributeMap: PropTypes.object.isRequired,

  // See SurveyListSiderbar
  surveyListData: PropTypes.array.isRequired,
};

/**
 * A wrapper component for the survey edit page's content
 * @param { Object } props -- see PropTypes
 * @return { JSX.Element }
*/
function SurveyEditorWrapper(props) {
  return (
    <ErrorBoundary
      FallbackComponent={ErrorFallback}
    >
      <DisabledFeaturesContext.Provider
        value={{
          disableStructuralChanges: props.disableStructuralChanges,
          readOnly: props.readOnly,
          surveyOverviewDocument: !props.isAdmin,
        }}
      >
        <SurveyEditor
          surveyId={props.surveyId}
          questionData={props.questionData}
          surveyData={props.surveyData}
          surveyPreviewData={props.surveyPreviewData}
          authenticityToken={props.authenticityToken}
          livePreviewUrl={props.livePreviewUrl}
          subnavLinks={props.subnavLinks}
          openTabName={props.openTabName}
          surveyGeneralOptions={props.surveyGeneralOptions}
          surveyTargetingOptions={props.surveyTargetingOptions}
          surveyFormattingOptions={props.surveyFormattingOptions}
          surveyTags={props.surveyTags}
          surveyListData={props.surveyListData}
          htmlAttributeMap={props.htmlAttributeMap}
        />
      </DisabledFeaturesContext.Provider>
    </ErrorBoundary>
  );
}

export default SurveyEditorWrapper;
