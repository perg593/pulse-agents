import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../CollapsiblePanel';

SchedulingOptions.propTypes = {
  scheduledReportLinks: PropTypes.object,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Scheduled report options
 * @param {object} props - see PropTypes
 * @return { JSX.Element }
 **/
function SchedulingOptions(props) {
  return (
    <div className='scheduling-options-container'>
      <CollapsiblePanel
        panelTitle='Scheduled Reports'
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        expandByDefault
        summary={props.scheduledReportLinks.edit.length}
      >
        <ul className='scheduled-report-list'>
          {
            props.scheduledReportLinks.edit.map((link) => {
              return (
                <li key={link.url}>
                  <a href={link.url}>{link.label}</a>
                </li>
              );
            })
          }
        </ul>
      </CollapsiblePanel>

      <hr/>

      <ul>
        <li>
          <a
            className='sidebar-button'
            href={props.scheduledReportLinks.new.url}
          >
            {props.scheduledReportLinks.new.label}
          </a>
        </li>
        <li>
          <a href={props.scheduledReportLinks.index.url}>
            {props.scheduledReportLinks.index.label}
          </a>
        </li>
      </ul>
    </div>
  );
};

export default SchedulingOptions;
