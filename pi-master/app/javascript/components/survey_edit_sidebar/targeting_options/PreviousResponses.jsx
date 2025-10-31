import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../../CollapsiblePanel';
import OptionsForSelect from '../../OptionsForSelect';

PreviousResponses.propTypes = {
  answerTrigger: PropTypes.object.isRequired,
  previousSurveyOptions: PropTypes.object,
  surveyOptions: PropTypes.array.isRequired,
  previousSurveyPossibleAnswerOptions: PropTypes.array.isRequired,
  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Render Previous Survey Responses panel
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function PreviousResponses(props) {
  return (
    <CollapsiblePanel
      panelTitle='Previous Responses'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
    >
      <div className='sidebar-option-row vertical'>
        <span>User answered survey:</span>

        <select
          value={props.answerTrigger.previousAnsweredSurveyId || ''}
          onChange={(e) => {
            const previousAnsweredSurveyId = e.target.value ? parseInt(e.target.value) : null;
            const previousPossibleAnswerId = props.previousSurveyPossibleAnswerOptions.length > 0 ? props.previousSurveyPossibleAnswerOptions[0].value : '';

            props.updateFunction(
                {
                  answerTrigger: {
                    ...props.answerTrigger,
                    previousAnsweredSurveyId: previousAnsweredSurveyId,
                    previousPossibleAnswerId: previousPossibleAnswerId,
                  },
                },
            );
          }}
        >
          <option key='previousAnswerSurveyIdPlaceholderOption' value=''>
            Select a survey
          </option>
          <OptionsForSelect options={props.surveyOptions} />
        </select>

        <span>with:</span>

        <select
          value={props.answerTrigger.previousPossibleAnswerId || ''}
          onChange={(e) => {
            const previousPossibleAnswerId = e.target.value ? parseInt(e.target.value) : null;

            props.updateFunction(
                {
                  answerTrigger: {
                    ...props.answerTrigger,
                    previousPossibleAnswerId: previousPossibleAnswerId,
                  },
                },
            );
          }}
          disabled={props.previousSurveyPossibleAnswerOptions.length === 0}
        >
          <OptionsForSelect options={props.previousSurveyPossibleAnswerOptions} />
        </select>
      </div>
    </CollapsiblePanel>
  );
}

export default PreviousResponses;
