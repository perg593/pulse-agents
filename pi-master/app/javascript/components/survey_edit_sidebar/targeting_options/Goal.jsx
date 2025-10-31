import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation} from '../../NumberValidations';

import CollapsiblePanel from '../../CollapsiblePanel';

Goal.propTypes = {
  goal: PropTypes.string.isRequired,
  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Render Goal settings panel
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function Goal(props) {
  return (
    <CollapsiblePanel
      panelTitle='Goal'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      summary={props.goal}
    >
      <div className='sidebar-option-row'>
        <NumberFormat
          value={props.goal}
          thousandSeparator={true}
          allowNegative={false}
          allowLeadingZeros={false}
          decimalSeparator={null}
          onBlur={(e) => {
            props.updateFunction({goal: e.target.value});
          }}
          isAllowed={(values) => {
            return minValidation(values, 0);
          }}
        />
      </div>
    </CollapsiblePanel>
  );
}

export default Goal;
