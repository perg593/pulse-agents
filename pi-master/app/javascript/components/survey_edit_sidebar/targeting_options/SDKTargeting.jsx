import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation} from '../../NumberValidations';

import CollapsiblePanel from '../../CollapsiblePanel';

SDKTargeting.propTypes = {
  mobileInstallTrigger: PropTypes.object.isRequired,
  mobileLaunchTrigger: PropTypes.object.isRequired,

  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Render SDK targeting panel
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function SDKTargeting(props) {
  return (
    <CollapsiblePanel
      panelTitle='SDK Targeting'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
    >
      <div className='sidebar-option-row horizontal'>
        <div className='description'>
          <span>Require at least</span>
        </div>
        <div className='options'>
          <NumberFormat
            id='mobile_days_installed_field'
            className='number-input'
            value={props.mobileInstallTrigger.mobileDaysInstalled || 0}
            allowNegative={false}
            decimalSeparator={null}
            onBlur={(e) => {
              props.updateFunction(
                  {
                    mobileInstallTrigger: {
                      ...props.mobileInstallTrigger,
                      mobileDaysInstalled: e.target.value,
                    },
                  },
              );
            }}
            isAllowed={(values) => {
              return minValidation(values, 0);
            }}
          />
          <span>
            days since install
          </span>
        </div>
      </div>

      <div className='sidebar-option-row horizontal'>
        <div className='description'>
          <span>Require at least</span>
        </div>
        <div className='options'>
          <NumberFormat
            id='mobile_launch_times_field'
            className='number-input'
            value={props.mobileLaunchTrigger.mobileLaunchTimes || 0}
            allowNegative={false}
            decimalSeparator={null}
            onBlur={(e) => {
              props.updateFunction(
                  {
                    mobileLaunchTrigger: {
                      ...props.mobileLaunchTrigger,
                      mobileLaunchTimes: e.target.value,
                    },
                  },
              );
            }}
            isAllowed={(values) => {
              return minValidation(values, 0);
            }}
          />
          <span>
            launches
          </span>
        </div>
      </div>
    </CollapsiblePanel>
  );
}

export default SDKTargeting;
