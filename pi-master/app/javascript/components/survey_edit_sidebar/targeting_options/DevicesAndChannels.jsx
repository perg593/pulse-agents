import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../../CollapsiblePanel';

import DesktopIcon from '../../../images/survey_editor/monitor.svg';
import TabletIcon from '../../../images/survey_editor/tablet.svg';
import MobileIcon from '../../../images/survey_editor/mobile_alt.svg';
import LaptopIcon from '../../../images/survey_editor/laptop.svg';
import GlobeIcon from '../../../images/survey_editor/globe.svg';
import IosIcon from '../../../images/survey_editor/ios.svg';
import AndroidIcon from '../../../images/survey_editor/android.svg';
import EmailIcon from '../../../images/survey_editor/email.svg';

DevicesAndChannels.propTypes = {
  targetingOptions: PropTypes.object.isRequired,
  updateFunction: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};

/**
 * Render Devices and Channels settings panel
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function DevicesAndChannels(props) {
  const DeviceIcon = ({icon, optionKey}) => {
    return (
      <li
        className={`device-trigger-icon ${props.targetingOptions[optionKey]? 'checked' : ''}`}
        style={{
          maskImage: `url(${icon})`,
          WebkitMaskImage: `url(${icon})`,
        }}
        onClick={
          (e) => {
            const newObject = {};
            newObject[optionKey] = !props.targetingOptions[optionKey];
            props.updateFunction(newObject);
          }
        }
      />
    );
  };
  DeviceIcon.propTypes = {
    icon: PropTypes.string.isRequired,
    optionKey: PropTypes.string.isRequired,
  };

  return (
    <CollapsiblePanel
      panelTitle='Devices & Channels'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
    >
      <ul className='device-trigger-list'>
        <DeviceIcon icon={DesktopIcon} optionKey='desktopEnabled' />
        <DeviceIcon icon={TabletIcon} optionKey='tabletEnabled' />
        <DeviceIcon icon={MobileIcon} optionKey='mobileEnabled' />
        <DeviceIcon icon={IosIcon} optionKey='iosEnabled' />
        <DeviceIcon icon={AndroidIcon} optionKey='androidEnabled' />
        <DeviceIcon icon={EmailIcon} optionKey='emailEnabled' />
      </ul>
    </CollapsiblePanel>
  );
}

export default DevicesAndChannels;
