import React from 'react';
import PropTypes from 'prop-types';

import DebouncedInput from '../../DebouncedInput';
import CollapsiblePanel from '../../CollapsiblePanel';

import OptionsForSelect from '../../OptionsForSelect';

import InvalidSelectionWarning from './InvalidSelectionWarning';

VisitCount.propTypes = {
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  visitCountFilter: PropTypes.object,
  updateFunction: PropTypes.func.isRequired,
  valid: PropTypes.bool.isRequired,
  invalidHeaderMessage: PropTypes.string.isRequired,
  comparators: PropTypes.array.isRequired,
};

/**
 * The Visit Count  filtering panel
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function VisitCount(props) {
  const selectedComparator = () => {
    return props.comparators.find((comparator) => {
      return comparator.value === props.visitCountFilter?.comparator;
    });
  };

  const summary = () => {
    if (selectedComparator() && props.visitCountFilter) {
      const filter = props.visitCountFilter;

      return `${selectedComparator().label} ${filter.value}`;
    } else {
      return props.invalidHeaderMessage;
    }
  };

  return (
    <CollapsiblePanel
      summary={summary()}
      panelTitle='Visit Count'
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
              ...props.visitCountFilter,
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
          id='visit_count_value_field'
          name='visit count'
          value={props.visitCountFilter?.value ?? ''}
          size={10}
          type='numeric'
          pattern='\d*'
          min={0}
          onChange={(value) => {
            const newFilter = {
              ...props.visitCountFilter,
              value: value,
            };

            props.updateFunction(newFilter);
          }}
        />
      </div>
    </CollapsiblePanel>
  );
}

export default VisitCount;
