import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../../CollapsiblePanel';

import SettingsIcon from '../SettingsIcon';

import DesktopIcon from '../../../images/survey_editor/monitor.svg';
import TabletIcon from '../../../images/survey_editor/tablet.svg';
import MobileIcon from '../../../images/survey_editor/mobile_alt.svg';

import InvalidSelectionWarning from './InvalidSelectionWarning';

Devices.propTypes = {
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  deviceFilters: PropTypes.array.isRequired,
  updateFunction: PropTypes.func.isRequired,
  valid: PropTypes.bool.isRequired,
  invalidHeaderMessage: PropTypes.string.isRequired,
};

/**
 * The Devices filtering panel
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function Devices(props) {
  const filters = {
    desktop: {
      name: 'desktop',
      icon: DesktopIcon,
    },
    tablet: {
      name: 'tablet',
      icon: TabletIcon,
    },
    mobile: {
      name: 'mobile',
      icon: MobileIcon,
    },
  };

  /**
   * Select all device filters
   */
  function selectAll() {
    props.updateFunction(Object.values(filters).map((filter) => filter.name));
  }

  return (
    <CollapsiblePanel
      summary={`${props.deviceFilters.length || props.invalidHeaderMessage}`}
      panelTitle='Device Type'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
      additionalHeaderClasses={props.valid ? null : 'invalid-selection'}
    >
      <InvalidSelectionWarning
        valid={props.valid}
        message="Please select at least one device type"
      />
      <ul className='device-list'>
        {
          Object.values(filters).map((filter) => {
            return (
              <DeviceIcon
                key={filter.name}
                icon={filter.icon}
                device={filter.name}
                updateFunction={props.updateFunction}
                deviceFilters={props.deviceFilters}
              />
            );
          })
        }
        <li>
          <button href="#" onClick={selectAll}>Select all</button>
        </li>
      </ul>
    </CollapsiblePanel>
  );
}

const DeviceIcon = (props) => {
  const toggleDeviceFilter = () => {
    const urlFilters = [...props.deviceFilters];
    const index = urlFilters.indexOf(props.device);

    if (index == -1) {
      urlFilters.push(props.device);
    } else {
      urlFilters.splice(index, 1);
    }

    props.updateFunction(urlFilters);
  };

  const iconClasses = () => {
    return props.deviceFilters.includes(props.device) ? 'checked' : '';
  };

  return (
    <li className='settings-option' onClick={toggleDeviceFilter}>
      <SettingsIcon icon={props.icon} additionalClasses={iconClasses()} />
    </li>
  );
};
DeviceIcon.propTypes = {
  deviceFilters: PropTypes.array.isRequired,
  updateFunction: PropTypes.func.isRequired,
  device: PropTypes.string.isRequired,
  icon: PropTypes.string.isRequired,
};

export default Devices;
