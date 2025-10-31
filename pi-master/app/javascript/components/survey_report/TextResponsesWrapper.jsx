import React from 'react';
import PropTypes from 'prop-types';

import {ErrorBoundary} from 'react-error-boundary';

import ErrorFallback from '../ErrorFallback';

import TextResponsesTable from './text_responses/TextResponsesTable.tsx';

TextResponsesWrapper.propTypes = {
  autotagEnabled: PropTypes.bool, // Whether or not the account has autotagging enabled
  answers: PropTypes.array, // Array of Answer records (see TextResponsesTable)
  tagsOptions: PropTypes.array, // Array of TagOption records (see TextResponsesTable)
  question: PropTypes.object, // Array of Answer records (see TextResponsesTable)
  surveyId: PropTypes.number, // The question's survey's ID (see TextResponsesTable)
};

/**
 * A wrapper component for the free text response page's content
 * @param { Object } props -- see PropTypes
 * @return { JSX.Element }
 */
function TextResponsesWrapper(props) {
  return (
    <ErrorBoundary FallbackComponent={ErrorFallback}>
      <TextResponsesTable
        autotagEnabled={props.autotagEnabled}
        question={props.question}
        tableData={props.tableData}
        tagOptions={props.tagOptions}
        surveyId={props.surveyId}
      />
    </ErrorBoundary>
  );
}

export default TextResponsesWrapper;
