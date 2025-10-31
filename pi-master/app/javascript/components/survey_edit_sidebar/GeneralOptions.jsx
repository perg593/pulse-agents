import React from 'react';
import PropTypes from 'prop-types';

import Select from 'react-select';

import CollapsiblePanel from '../CollapsiblePanel';
import PiModal from '../modal_dialog/PiModal';

import Brief from './general_options/Brief';
import SurveyOverviewDocument from './general_options/SurveyOverviewDocument';

import * as htmlToImage from 'html-to-image';
import { toPng } from 'html-to-image';

GeneralOptions.propTypes = {
  surveyId: PropTypes.number.isRequired,
  setTagSelections: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  appliedSurveyTags: PropTypes.array.isRequired,
  unappliedSurveyTags: PropTypes.array.isRequired,
  setGeneralOptions: PropTypes.func.isRequired,
  generalOptions: PropTypes.object.isRequired,
};

/**
 * Render survey general tab
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function GeneralOptions(props) {
  const updateGeneralOption = (newObject) => {
    props.setGeneralOptions({
      ...props.generalOptions,
      ...newObject,
    });
  };

  const auditSample = props.generalOptions.auditLog.slice(0, 2);

  AuditModal.propTypes = {
    auditLog: PropTypes.array.isRequired,
  };
  /**
   * Render survey audit log modal
   * @param {object} props - see propTypes
   * @return {JSX.Element}
  */
  function AuditModal(props) {
    const dialogRef = React.useRef(null);

    const openDialog = () => {
      if (dialogRef.current) {
        dialogRef.current.showModal();
      }
    };

    return (
      <>
        <input
          type='button'
          className='sidebar-button audit-log-trigger'
          onClick={openDialog}
          value='MORE'
        />

        <PiModal
          ref={dialogRef}
          modalClassName='audit-modal'
        >
          <PiModal.Header
            title='Last 10 Audits'
            titleClassName='settings-modal-title'
          />
          <PiModal.Body>
            <ul className='audit-list'>
              {
                props.auditLog.map((audit) => {
                  return <AuditLine audit={audit} key={audit.createdAt}/>;
                })
              }
            </ul>
          </PiModal.Body>
          <PiModal.Footer>
            <a
              className='sidebar-button'
              href='/my_account/audit/'
              target='_blank'
            >
              See All
            </a>
          </PiModal.Footer>
        </PiModal>
      </>
    );
  }

  AuditLine.propTypes = {
    audit: PropTypes.object.isRequired,
  };
  /**
   * Render a single audited change
   * TODO: Handle the many audit edge cases
   *
   * @param {object} audit
   * @return {JSX.Element}
  */
  function AuditLine({audit}) {
    return (
      <li>
        {audit.createdAt} - { audit.username } - { audit.actionDescription }

        {
          audit.values ?
            <ul>
              {
                Object.keys(audit.values[0]).map((key) => {
                  let change = '';

                  if (Array.isArray(audit.values[0][key])) {
                    const oldValue = audit.values[0][key][0];
                    const newValue = audit.values[0][key][1];

                    change = `${oldValue} - ${newValue}`;
                  } else {
                    change = `${audit.values[0][key]}`;
                  }

                  return <li key={key}>{key}: {change}</li>;
                })
              }
            </ul> :
              null
        }
      </li>
    );
  }

  AuditLogPanel.propTypes = {
    auditLog: PropTypes.array.isRequired,
    panelExpansionSettings: PropTypes.object.isRequired,
    updatePanelExpansionSettings: PropTypes.func.isRequired,
  };
  /**
   * Render the audit log panel
   * @param {object} auditLog
   * @return {JSX.Element}
  */
  function AuditLogPanel({auditLog}) {
    if (auditLog.length == 0) {
      return null;
    }

    return (
      <CollapsiblePanel
        panelTitle='Audit Log'
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        expandByDefault
      >
        <ul>
          {
            auditSample.map((audit) => {
              return <AuditLine audit={audit} key={audit.createdAt}/>;
            })
          }
        </ul>
        {
          auditLog.length > 2 ? <AuditModal auditLog={auditLog} /> : null
        }
      </CollapsiblePanel>
    );
  }

  const onTagSelectionChange = (selectedOptions) => {
    props.setTagSelections(selectedOptions);
  };

  return (
    <>
      <CollapsiblePanel
        panelTitle='Tags'
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        expandByDefault
      >
        <Select
          defaultValue={props.appliedSurveyTags}
          isMulti
          options={props.unappliedSurveyTags}
          className="basic-multi-select tag-selector"
          classNamePrefix="select"
          onChange={onTagSelectionChange}
        />

        <a
          className='sidebar-button'
          href='/survey_tags'
          target='_blank'
        >
          MANAGE TAGS
        </a>
      </CollapsiblePanel>

      {
        props.generalOptions.surveyBriefEnabled ?
          <Brief
            surveyId={props.surveyId}
            panelExpansionSettings={props.panelExpansionSettings}
            updatePanelExpansionSettings={props.updatePanelExpansionSettings}
            surveyBriefJob={props.generalOptions.surveyBriefJob}
            authenticityToken={props.generalOptions.authenticityToken}
            updateFunction={updateGeneralOption}
          /> : null
      }

      <SurveyOverviewDocument
        surveyId={props.surveyId}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        authenticityToken={props.generalOptions.authenticityToken}
        surveyOverviewDocument={props.generalOptions.surveyOverviewDocument}
        updateFunction={updateGeneralOption}
      />

      <AuditLogPanel
        auditLog={props.generalOptions.auditLog}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
    </>
  );
}

export default GeneralOptions;
