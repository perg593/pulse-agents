import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../../CollapsiblePanel';
import Spinner from '../../Spinner';
import SparklesIcon from '../../../images/sparkles.svg';

Brief.propTypes = {
  surveyId: PropTypes.number.isRequired,
  surveyBriefJob: PropTypes.object.isRequired,
  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  authenticityToken: PropTypes.string.isRequired,
};

/**
 * Render Brief panel
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function Brief(props) {
  const [briefGenerationFailed, setBriefGenerationFailed] = React.useState(false);

  const polling = !briefGenerationFailed &&
    props.surveyBriefJob.id !== null &&
    props.surveyBriefJob.status !== 'done' &&
    props.surveyBriefJob.status !== 'failed';

  /**
   * Polls the survey brief job. When it's done update our model
   **/
  function pollForBrief() {
    fetch(
        `/survey_brief_jobs/${props.surveyBriefJob.id}`,
        {
          method: 'GET',
          headers: {
            'Accept': 'application/json',
          },
        },
    ).then((response) => {
      if (response.ok) {
        response.json().then((json) => {
          if (json.status === 'done') {
            props.updateFunction({
              surveyBriefJob: {
                ...props.surveyBriefJob,
                brief: json.brief,
                status: json.status,
              },
            });
          } else if (json.status === 'failed') {
            props.updateFunction({
              surveyBriefJob: {
                ...props.surveyBriefJob,
                status: json.status,
              },
            });
          } else {
            setTimeout(pollForBrief, 1000);
          }
        });
      }
    });
  }

  React.useEffect(() => {
    if (polling) {
      pollForBrief();
    }
  }, [props.surveyBriefJob.status]);

  /**
   * Submit a request for a new survey brief
   * Store the returned survey_brief_job_id in state
   **/
  function requestBrief() {
    fetch(
        `/survey_brief_jobs?survey_brief_job[survey_id]=${props.surveyId}&authenticity_token=${props.authenticityToken}`,
        {
          method: 'POST',
          headers: {
            'Accept': 'application/json',
          },
        },
    ).then((response) => {
      if (response.ok) {
        response.json().then((json) => {
          props.updateFunction({
            surveyBriefJob: {
              ...props.surveyBriefJob,
              id: json.id,
              brief: null,
              status: 'pending',
            },
          });
        });
      } else {
        setBriefGenerationFailed(true);
      }
    });
  }

  /**
   * Message to show when brief is being generated
   * @return {JSX.Element}
   **/
  function PollingContent() {
    return (
      <>
        <p className='loading-message'>Generating...</p>
        <Spinner />
      </>
    );
  }

  /**
   * Message to show when brief generation failed
   * @return {JSX.Element}
   **/
  function ErrorContent() {
    return (
      <p className='error-message'>
        We ran into an issue generating your survey brief. Please check the
        survey configuration and try again. If the problem persists, contact
        support.
      </p>
    );
  }

  /**
   * Render the brief editor
   * @return {JSX.Element}
   */
  function BriefEditor() {
    return (
      <textarea
        className='survey-brief-text-area'
        defaultValue={props.surveyBriefJob?.brief}
        onBlur={(e) => {
          props.updateFunction({
            surveyBriefJob: {
              ...props.surveyBriefJob,
              brief: e.target.value,
            },
          });
        }}
      />
    );
  }

  /**
   * Render the panel contents
   * @return {JSX.Element}
   */
  function PanelContents() {
    if (polling) {
      return <PollingContent />;
    } else if (props.surveyBriefJob.status === 'failed') {
      return <ErrorContent />;
    } else if (briefGenerationFailed) {
      return <ErrorContent />;
    } else if (props.surveyBriefJob.status === 'done') {
      return <BriefEditor />;
    } else {
      return (
        <button
          type='button'
          className='sidebar-button with-icon'
          onClick={() => requestBrief()}
        >
          <img src={SparklesIcon} />
          <span>GENERATE BRIEF</span>
        </button>
      );
    }
  }

  return (
    <CollapsiblePanel
      panelTitle='Brief'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
    >
      <div className='sidebar-option-row horizontal'>
        <PanelContents />
      </div>
    </CollapsiblePanel>
  );
}

export default Brief;
