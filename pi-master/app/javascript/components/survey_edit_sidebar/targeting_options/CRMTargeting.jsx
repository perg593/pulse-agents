import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../../CollapsiblePanel';
import DeleteButton from '../../DeleteButton';
import OptionsForSelect from '../../OptionsForSelect';

CRMTargeting.propTypes = {
  clientKeyTrigger: PropTypes.object.isRequired,
  deviceTriggers: PropTypes.array.isRequired,
  deviceTriggerMatcherOptions: PropTypes.array.isRequired,
  updateFunction: PropTypes.func.isRequired,
  onArrayPropertyChange: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  deleteArrayItem: PropTypes.func.isRequired,
};

/**
 * The CRM Targeting panel
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function CRMTargeting(props) {
  const DeviceTrigger = ({index, deviceDataMandatory}) => {
    const trigger = props.deviceTriggers[index];

    if (trigger.flaggedForDeletion) {
      return null;
    }

    if (trigger.deviceDataMandatory !== deviceDataMandatory) {
      return null;
    }

    return (
      <div className='trigger-wrapper'>
        <div className='control-wrapper'>
          <div className='sidebar-option-row vertical'>
            <input
              placeholder='Attribute'
              defaultValue={trigger.deviceDataKey}
              onBlur={(e) => {
                props.onArrayPropertyChange(
                    index,
                    'deviceTriggers',
                    {deviceDataKey: e.target.value},
                );
              }}
            />
            <select
              value={trigger.deviceDataMatcher}
              onChange={(e) => {
                props.onArrayPropertyChange(
                    index,
                    'deviceTriggers',
                    {deviceDataMatcher: e.target.value},
                );
              }}
            >
              <OptionsForSelect options={props.deviceTriggerMatcherOptions} />
            </select>

            {
              ['is_true', 'is_not_true'].includes(trigger.deviceDataMatcher) ?
                null :
                  <input
                    defaultValue={trigger.deviceDataValue}
                    onBlur={(e) => {
                      props.onArrayPropertyChange(
                          index,
                          'deviceTriggers',
                          {deviceDataValue: e.target.value},
                      );
                    }}
                  />
            }
          </div>
        </div>
        <div className='delete-button-wrapper'>
          <DeleteButton
            onClick={(e) => props.deleteArrayItem(index, 'deviceTriggers')}
          />
        </div>
      </div>
    );
  };
  DeviceTrigger.propTypes = {
    index: PropTypes.number.isRequired,
    deviceDataMandatory: PropTypes.bool.isRequired,
  };

  const DeviceTriggerOptions = ({deviceDataMandatory}) => {
    return (
      <>
        <div className='sidebar-label'>
          { deviceDataMandatory ? 'Matches all of' : 'Matches any one of' }:
        </div>

        {
          props.deviceTriggers.map((trigger, i) => {
            return <DeviceTrigger
              key={`${trigger.deviceDataMandatory}_${trigger.deviceDataKey}_${trigger.deviceDataMatcher}_${trigger.deviceDataValue}`}
              index={i}
              deviceDataMandatory={deviceDataMandatory}
            />;
          })
        }

        <input
          type='button'
          className='sidebar-button new-crm-button'
          onClick={() => {
            props.onArrayPropertyChange(null, 'deviceTriggers', {
              deviceDataMandatory: deviceDataMandatory,
              deviceDataMatcher: 'is',
            });
          }}
          value='ADD NEW'
        />
      </>
    );
  };
  DeviceTriggerOptions.propTypes = {
    deviceDataMandatory: PropTypes.bool.isRequired,
  };

  return (
    <CollapsiblePanel
      panelTitle='CRM Targeting'
      panelClass='crm-targeting-panel'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
    >
      <DeviceTriggerOptions deviceDataMandatory={true} />
      <DeviceTriggerOptions deviceDataMandatory={false} />

      <div className='sidebar-option-row horizontal'>
        <input
          type="checkbox"
          id='client-key-presence-field'
          onChange={(e) => {
            props.updateFunction(
                {
                  clientKeyTrigger: {
                    ...props.clientKeyTrigger,
                    clientKeyPresence: e.target.checked,
                  },
                },
            );
          }}
          value={props.clientKeyTrigger.clientKeyPresence || ''}
          checked={props.clientKeyTrigger.clientKeyPresence}
        />
        <label
          className='sidebar-label'
          htmlFor='client-key-presence-field'
        >
          Display only if client_key is defined
        </label>
      </div>
    </CollapsiblePanel>
  );
}

export default CRMTargeting;
