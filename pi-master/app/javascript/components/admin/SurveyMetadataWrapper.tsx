import React from 'react';

import {ErrorBoundary} from 'react-error-boundary';
import ErrorFallback from '../ErrorFallback';
import SurveyMetadata from './SurveyMetadata';

interface SurveyMetadataWrapperProps {
};

/**
 * @param { SurveyMetadataWrapperProps } props -- see interface above
 * @return { JSX.Element }
*/
function SurveyMetadataWrapper(props: SurveyMetadataWrapperProps) {
  return (
    <ErrorBoundary FallbackComponent={ErrorFallback}>
      <SurveyMetadata {...props.props}/>
    </ErrorBoundary>
  );
}

export default SurveyMetadataWrapper;
