import React from 'react';

import OutsideClickHandler from 'react-outside-click-handler';

import 'react-tooltip/dist/react-tooltip.css';
import { Tooltip } from 'react-tooltip';

import {AutoTagAnswersResponseTags} from './Types';

interface AutotagMenuProps {
  questionId: number
  selectedRows: Array<Object>
  setWorking: (working: boolean) => void
  markAppliedTagsAsApprovedForAnswers: (answerIds: Array<number>) => void
  removeAppliedTagsFromAnswers: (answerIds: Array<number>) => void
  addNewAppliedTags: (tags: Array<AutoTagAnswersResponseTags>) => void
  disabled: boolean
}

/**
 * A menu offering bulk autotag actions for selected answers
 *
 * @param {AutotagMenuProps} props
 * @return {JSX.Element}
 **/
function AutotagMenu(props: AutotagMenuProps) {
  const [showPanel, setShowPanel] = React.useState(false);
  const [panelPosition, setPanelPosition] = React.useState([0, 0]);

  const activatePanel = (e) => {
    setShowPanel(true);
    setPanelPosition([e.clientX, e.clientY]);
  };

  const selectedAnswerIds = props.selectedRows.map((row) => {
    return row.getValue('answerId');
  });

  /**
   * Shared code for all bulk tagging requests
   *
   * @param { object } requestParams - parameters for AJAX call
   * @param { function} successHandler - a function to perform on success
   **/
  function requestUpdate(requestParams: object, successHandler: Function) {
    setShowPanel(false);
    props.setWorking(true);

    $.ajax(requestParams).done(function(responseData) {
      successHandler(responseData);
      console.debug('We did it!');
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed to update! D:', jqXHR, textStatus, errorThrown);
      alert('Please try again or contact support@pulseinsights.com');
    }).always(function() {
      props.setWorking(false);
    });
  }

  /**
   * Request autotagging of all selected answers
   **/
  function requestAutotagging() {
    const tagAutomationJobAnswersAttributes = {};
    selectedAnswerIds.forEach((selectedAnswerId, index) => {
      tagAutomationJobAnswersAttributes[index.toString()] = {
        answer_id: selectedAnswerId,
      };
    });
    requestUpdate({
      url: `/questions/${props.questionId}/auto_tag_answers`,
      method: 'POST',
      data: {
        tag_automation_job: {
          tag_automation_job_answers_attributes: tagAutomationJobAnswersAttributes,
        },
      },
    },
    (responseData) => {
      pollTagAutomationJob(responseData.tagAutomationJobId);
    });
  }

  /**
   * Poll auto-applied tags every 2 seconds
   *
   * @param { object } tagAutomationJobId - Id corresponding to the request made via #requestAutotagging
   **/
  function pollTagAutomationJob(tagAutomationJobId) {
    const intervalId = setInterval(() => {
      $.ajax({
        url: `/tag_automation_jobs/${tagAutomationJobId}/poll`,
        method: 'GET',
      }).done(function(response) {
        if (response.status != 'completed') return;
        props.addNewAppliedTags(response.appliedTags);
        clearInterval(intervalId);
      });
    }, 2000); // Starting point, subject to change
  }

  /**
   * Tell server to approve each selected answer's automated tags
   **/
  function approveAll() {
    requestUpdate({
      url: '/tags/bulk_approve',
      method: 'PATCH',
      data: {
        answer_ids: selectedAnswerIds,
      },
    },
    (responseData) => {
      const answerIds = responseData.tags.map((tag) => {
        return tag.answer_id;
      });

      props.markAppliedTagsAsApprovedForAnswers(answerIds);
    });
  }

  /**
   * Unapply all tags from selected answers
   **/
  function removeAll() {
    requestUpdate({
      url: '/tags/bulk_remove',
      method: 'DELETE',
      data: {
        answer_ids: selectedAnswerIds,
      },
    },
    (responseData) => {
      const answerIds = responseData.tags.map((tag) => {
        return tag.answer_id;
      });

      props.removeAppliedTagsFromAnswers(answerIds);
    });
  }

  return (
    <>
      <button
        disabled={props.disabled}
        onClick={activatePanel}
        data-tooltip-id='autotag_menu_tooltip'
        data-tooltip-content={props.disabled ? 'Select one or more rows to tag.' : ''}
      >
        AutoTag
      </button>
      <Tooltip id='autotag_menu_tooltip' />

      {
        showPanel ?
          <div className='outside-click-handler-wrapper'>
            <OutsideClickHandler onOutsideClick={() => setShowPanel(false)} >
              <div
                className='popup-menu'
                style={{
                  left: `${panelPosition[0]}px`,
                  top: `${panelPosition[1]}px`,
                }}
              >
                <ul className='row-selection-list'>
                  <li>
                    <a onClick={() => requestAutotagging()}>
                      Run Autotag for selected response(s)
                    </a>
                  </li>
                  <li>
                    <a onClick={() => approveAll()}>Approve Suggested Tag</a>
                  </li>
                  <li>
                    <a onClick={() => removeAll()}>Reject Suggested Tag</a>
                  </li>
                </ul>
              </div>
            </OutsideClickHandler>
          </div> : null
      }
    </>
  );
}

export default AutotagMenu;
