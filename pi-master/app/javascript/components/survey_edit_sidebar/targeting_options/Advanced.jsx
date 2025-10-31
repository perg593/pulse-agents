import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation} from '../../NumberValidations';

import CollapsiblePanel from '../../CollapsiblePanel';
import OptionsForSelect from '../../OptionsForSelect';

Advanced.propTypes = {
  stopShowingWithoutAnswer: PropTypes.bool.isRequired,
  ignoreFrequencyCap: PropTypes.bool.isRequired,
  refireEnabled: PropTypes.bool.isRequired,
  refireTime: PropTypes.number,
  refireTimePeriod: PropTypes.string,
  refireTimePeriodOptions: PropTypes.array.isRequired,
  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Render advanced settings panel
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function Advanced(props) {
  return (
    <CollapsiblePanel
      panelTitle='Advanced'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
    >
      <div className='sidebar-option-row horizontal'>
        <input
          type="checkbox"
          id='stop_showing_without_answer_field'
          className='multi-line'
          onChange={(e) => {
            props.updateFunction({stopShowingWithoutAnswer: e.target.checked});
          }}
          value={props.stopShowingWithoutAnswer}
          checked={props.stopShowingWithoutAnswer}
        />
        <label
          className='sidebar-label multi-line'
          htmlFor='stop_showing_without_answer_field'
        >
          Don't show this survey again after a user closes it
        </label>
      </div>
      <div className='sidebar-option-row horizontal'>
        <input
          type="checkbox"
          id='ignore_frequency_cap_field'
          onChange={(e) => {
            props.updateFunction({ignoreFrequencyCap: e.target.checked});
          }}
          value={props.ignoreFrequencyCap}
          checked={props.ignoreFrequencyCap}
        />
        <label
          className='sidebar-label'
          htmlFor='ignore_frequency_cap_field'
        >
          Ignore frequency cap
        </label>
      </div>
      <div className='sidebar-option-row option-with-description-container'>
        <div className='checkbox-container'>
          <input
            type="checkbox"
            id='refire_enabled_field'
            onChange={(e) => {
              props.updateFunction({refireEnabled: e.target.checked});
            }}
            value={props.refireEnabled}
            checked={props.refireEnabled}
          />
        </div>
        <div className='description-container'>
          <div className='description'>
            <label
              className='sidebar-label'
              htmlFor='refire_enabled_field'
            >
              Enable refiring survey
            </label>
          </div>
          <div className='options'>
            <NumberFormat
              className='number-input'
              value={props.refireTime}
              isAllowed={(values) => {
                return minValidation(values, 0);
              }}
              onBlur={(e) => {
                props.updateFunction({refireTime: e.target.value});
              }}
            />
          </div>
          <div className='options'>
            <select
              value={props.refireTimePeriod || ''}
              onChange={(e) => {
                props.updateFunction({refireTimePeriod: e.target.value});
              }}
            >
              <OptionsForSelect options={props.refireTimePeriodOptions} />
            </select>
          </div>
          <div className='options'>
            <span>after a user submits</span>
          </div>
        </div>
      </div>
    </CollapsiblePanel>
  );
}

export default Advanced;
