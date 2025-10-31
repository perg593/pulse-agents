import React from 'react';

const DisabledFeaturesContext = React.createContext({
  disableStructuralChanges: false,
  readOnly: false,
  surveyOverviewDocument: false,
});

export default DisabledFeaturesContext;
