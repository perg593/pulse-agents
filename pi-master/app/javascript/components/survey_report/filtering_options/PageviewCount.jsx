import React from 'react';
import PropTypes from 'prop-types';

import DebouncedInput from '../../DebouncedInput';
import CollapsiblePanel from '../../CollapsiblePanel';

import OptionsForSelect from '../../OptionsForSelect';

import InvalidSelectionWarning from './InvalidSelectionWarning';

PageviewCount.propTypes = {
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  pageviewCountFilter: PropTypes.object,
  updateFunction: PropTypes.func.isRequired,
  valid: PropTypes.bool.isRequired,
  invalidHeaderMessage: PropTypes.string.isRequired,
  comparators: PropTypes.array.isRequired,
};

/**
 * The Pageview Count  filtering panel
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function PageviewCount(props) {
  const selectedComparator = () => {
    return props.comparators.find((comparator) => {
      return comparator.value === props.pageviewCountFilter?.comparator;
    });
  };

  const summary = () => {
    if (selectedComparator() && props.pageviewCountFilter) {
      const filter = props.pageviewCountFilter;

      return `${selectedComparator().label} ${filter.value}`;
    } else {
      return props.invalidHeaderMessage;
    }
  };

  return (
    <CollapsiblePanel
      summary={summary()}
      panelTitle='Pageview Count'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
      valid={props.valid}
      additionalHeaderClasses={props.valid ? null : 'invalid-selection'}
    >
      <InvalidSelectionWarning
        valid={props.valid}
        message="Please do something"
      />

      <div className='sidebar-option-row horizontal'>
        <select
          className='comparator-list'
          value={selectedComparator()?.value || ''}
          onChange={(e) => {
            const newFilter = {
              ...props.pageviewCountFilter,
              comparator: e.target.value,
            };

            props.updateFunction(newFilter);
          }}
        >
          <option value="" disabled>
            Select a comparator
          </option>
          <OptionsForSelect options={props.comparators} />
        </select>

        <DebouncedInput
          id='pageview_count_value_field'
          name='pageview count'
          value={props.pageviewCountFilter?.value ?? ''}
          size={10}
          type='numeric'
          pattern='\d*'
          min={0}
          onChange={(value) => {
            const newFilter = {
              ...props.pageviewCountFilter,
              value: value,
            };

            props.updateFunction(newFilter);
          }}
        />
      </div>
    </CollapsiblePanel>
  );
}

export default PageviewCount;
