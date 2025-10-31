import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation, maxValidation} from '../../NumberValidations';

import CollapsiblePanel from '../../CollapsiblePanel';

SampleRate.propTypes = {
  value: PropTypes.number.isRequired,
  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Render sample rate settings panel
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function SampleRate(props) {
  return (
    <CollapsiblePanel
      panelTitle='Sample Rate'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      summary={props.value ? `${props.value}%` : null}
    >
      <div className='sidebar-option-row horizontal'>
        <label
          className='sidebar-label'
          htmlFor='sample_rate_field'
        >
          Sample Rate
        </label>
        <NumberFormat
          id='sample_rate_field'
          className='number-input'
          value={props.value}
          allowNegative={false}
          allowLeadingZeros={false}
          decimalSeparator={null}
          isAllowed={(values) => {
            return minValidation(values, 0) && maxValidation(values, 100);
          }}
          onBlur={(e) => props.updateFunction({sampleRate: e.target.value})}
        />
      </div>
    </CollapsiblePanel>
  );
}

export default SampleRate;
