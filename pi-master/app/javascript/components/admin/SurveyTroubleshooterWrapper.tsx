import React from 'react';

import {ErrorBoundary} from 'react-error-boundary';
import ErrorFallback from '../ErrorFallback';
import SurveyTroubleshooter from './SurveyTroubleshooter';

interface SurveyTroubleshooterWrapperProps {
};

/**
 * @param { SurveyTroubleshooterWrapperProps } props -- see interface above
 * @return { JSX.Element }
*/
function SurveyTroubleshooterWrapper(props: SurveyTroubleshooterWrapperProps) {
  return (
    <ErrorBoundary FallbackComponent={ErrorFallback}>
      <SurveyTroubleshooter {...props.props}/>
    </ErrorBoundary>
  );
}

export default SurveyTroubleshooterWrapper;
