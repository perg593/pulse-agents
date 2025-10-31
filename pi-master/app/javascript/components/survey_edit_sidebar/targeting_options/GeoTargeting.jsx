import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../../CollapsiblePanel';
import DeleteButton from '../../DeleteButton';
import OptionsForSelect from '../../OptionsForSelect';

GeoTargeting.propTypes = {
  geoipTriggers: PropTypes.array.isRequired,
  geoipTriggerOptions: PropTypes.object.isRequired,
  onArrayPropertyChange: PropTypes.func.isRequired,
  deleteArrayItem: PropTypes.func.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
};

/**
 * The UrlsAndEvents sidebar panel
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function GeoTargeting(props) {
  const CountrySelector = ({index, trigger}) => {
    return (
      <select
        value={trigger.geoCountry}
        onChange={(e) => {
          props.onArrayPropertyChange(
              index,
              'geoipTriggers',
              {geoCountry: e.target.value},
          );
        }}
      >
        <OptionsForSelect options={props.geoipTriggerOptions.countries} />
      </select>
    );
  };
  CountrySelector.propTypes = {
    trigger: PropTypes.object.isRequired,
    index: PropTypes.number.isRequired,
  };

  const StateTrigger = ({index, trigger}) => {
    return (
      <>
        <span>In State or DMA</span>
        <select
          value={trigger.geoStateOrDma}
          onChange={(e) => {
            props.onArrayPropertyChange(
                index,
                'geoipTriggers',
                {geoStateOrDma: e.target.value},
            );
          }}
        >
          <OptionsForSelect options={[{label: 'Any', value: ''}]} />
          <OptionsForSelect options={props.geoipTriggerOptions.states} />
          <OptionsForSelect options={props.geoipTriggerOptions.dmas} />
        </select>
      </>
    );
  };
  StateTrigger.propTypes = {
    trigger: PropTypes.object.isRequired,
    index: PropTypes.number.isRequired,
  };

  return (
    <CollapsiblePanel
      panelTitle='Geo Targeting'
      panelClass='geo-targeting-panel'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
    >
      {
        props.geoipTriggers.map((trigger, i) => {
          if (trigger.flaggedForDeletion) {
            return null;
          }

          const inUS = trigger.geoCountry === 'United States';

          return (
            <div
              className='trigger-wrapper geo-targeting'
              key={`${trigger.geoCountry}_${trigger.geoStateOrDma}`}
            >
              <div className='control-wrapper'>
                <div className='sidebar-option-row vertical'>
                  <span>Country</span>
                  <CountrySelector index={i} trigger={trigger}/>

                  { inUS ? <StateTrigger index={i} trigger={trigger}/> : null }
                </div>
              </div>
              <div className='delete-button-wrapper'>
                <DeleteButton
                  onClick={(e) => props.deleteArrayItem(i, 'geoipTriggers')}
                />
              </div>
            </div>
          );
        })
      }

      <div className='sidebar-option-row'>
        <input
          type='button'
          className='sidebar-button'
          onClick={() => {
            props.onArrayPropertyChange(null, 'geoipTriggers', {
              geoCountry: '',
              geoStateOrDma: '',
            });
          }}
          value='ADD NEW'
        />
      </div>
    </CollapsiblePanel>
  );
}

export default GeoTargeting;
