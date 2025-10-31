import React from 'react';
import PropTypes from 'prop-types';

import {ErrorBoundary} from 'react-error-boundary';

import ErrorFallback from '../ErrorFallback';
import SubmissionGeneratorForm from './SubmissionGeneratorForm';

import Otter from '../admin/Otter';
import OtterImage from '../../images/otters/otter.jpg';

SubmissionGenerator.propTypes = {
  authenticityToken: PropTypes.string.isRequired,
  formUrl: PropTypes.string.isRequired,
  questionLookupUrl: PropTypes.string.isRequired,
};

/**
 * A wrapper for the submission generator page
 * @param { Object } props - see propTypes above
 *
 * @return { JSX.Element } The form
 */
function SubmissionGenerator(props) {
  return (
    <ErrorBoundary FallbackComponent={ErrorFallback}>
      <h1>Submission Data Generator</h1>
      <SubmissionGeneratorForm
        authenticityToken={props.authenticityToken}
        formUrl={props.formUrl}
        questionLookupUrl={props.questionLookupUrl}
      />
      <Otter image={OtterImage} title="Otto" />
    </ErrorBoundary>
  );
}

export default SubmissionGenerator;
