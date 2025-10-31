import React from 'react';
import PropTypes from 'prop-types';

import DebouncedInput from '../../DebouncedInput';
import CollapsiblePanel from '../../CollapsiblePanel';

import DeleteButton from '../../DeleteButton';
import LocalizedSurveyIcon from '../../../images/survey_dashboard/localized_survey.svg';

import {CompletionUrlFilter} from './CompletionUrlFilter';
import OptionsForSelect from '../../OptionsForSelect';

CompletionUrl.propTypes = {
  panelExpansionSettings: PropTypes.object.isRequired, // see CollapsiblePanel
  updatePanelExpansionSettings: PropTypes.func.isRequired, // see CollapsiblePanel
  completionUrlFilters: PropTypes.array.isRequired, // current filter set
  updateFunction: PropTypes.func.isRequired, // updates the parent's filters
  completionUrlMatchers: PropTypes.array.isRequired, // options for matchers
};

/**
 * The CompletionUrl filtering panel
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
 */
function CompletionUrl(props) {
  const NewFilterButton = ({cumulative}) => {
    return (
      <input
        type='button'
        className='sidebar-button new-trigger-button'
        onClick={() => {
          // highest ID value + 1
          let newId = 0;
          if (props.completionUrlFilters.length) {
            newId = props.completionUrlFilters.reduce((prev, cur) => {
              return cur.id > prev.id ? cur : prev;
            }).id + 1;
          }

          const newFilters = [
            ...props.completionUrlFilters,
            new CompletionUrlFilter(newId, 'contains', '', cumulative),
          ];

          props.updateFunction(newFilters);
        }}
        value='ADD NEW'
      />
    );
  };
  NewFilterButton.propTypes = {
    cumulative: PropTypes.bool.isRequired, // ANY vs ALL
  };

  const IndividualFilter = ({filter}) => {
    /**
     * The array index of a filter
     * @param {number} id - The ID of the filter
     * @return {number} the array index of the filter
    */
    function findIndexByFilterId(id) {
      return props.completionUrlFilters.findIndex((_filter) => _filter.id === id);
    }

    /**
     * Update filter array (PUT style)
     * @param {number} id - The ID of the filter to change
     * @param {array} newVals - The new data for the updated filter
     * @return {number} the array index of the filter
    */
    function updateFilterArray(id, newVals) {
      const newFilters = [...props.completionUrlFilters];
      newFilters[findIndexByFilterId(id)] = new CompletionUrlFilter(
          newVals.id, newVals.matcher, newVals.value, newVals.cumulative,
      );
      return newFilters;
    }

    return (
      <div className='trigger-wrapper'>
        <div className='control-wrapper'>
          <div className='sidebar-option-row url-trigger-row'>
            <select
              className='trigger-option-field'
              value={filter.matcher}
              onChange={(e) => {
                const newVals = {
                  ...filter,
                  matcher: e.target.value,
                };

                const newFilters = updateFilterArray(filter.id, newVals);

                props.updateFunction(newFilters);
              }}
            >
              <OptionsForSelect options={props.completionUrlMatchers} />
            </select>
          </div>
          <div className='sidebar-option-row horizontal url-trigger-row'>
            <img
              className="grouping-icon"
              src={LocalizedSurveyIcon}
            />
            <DebouncedInput
              type='text'
              className='url-field'
              defaultValue={filter.value}
              title={filter.value}
              onChange={(value) => {
                const newVals = {
                  ...filter,
                  value: value,
                };

                const newFilters = updateFilterArray(filter.id, newVals);

                props.updateFunction(newFilters);
              }}
            />
          </div>
        </div>
        <div className='delete-button-wrapper'>
          <DeleteButton
            onClick={(e) => {
              const newFilters = [...props.completionUrlFilters];
              const indexToRemove = findIndexByFilterId(filter.id);
              newFilters.splice(indexToRemove, 1);

              props.updateFunction(newFilters);
            }}
          />
        </div>
      </div>
    );
  };
  IndividualFilter.propTypes = {
    filter: PropTypes.instanceOf(CompletionUrlFilter).isRequired,
  };

  const cumulativeFilters = [];
  const nonCumulativeFilters = [];
  props.completionUrlFilters.forEach((filter) => {
    if (filter.cumulative) {
      cumulativeFilters.push(filter);
    } else {
      nonCumulativeFilters.push(filter);
    }
  });

  return (
    <CollapsiblePanel
      summary={`${props.completionUrlFilters.length || ''}`}
      panelTitle='Completion URL'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
    >
      <h4>Matches all of:</h4>
      {
        cumulativeFilters.map((filter) => {
          return <IndividualFilter key={filter.id} filter={filter} />;
        })
      }
      <NewFilterButton cumulative={true} />

      <h4>Matches any one of:</h4>
      {
        nonCumulativeFilters.map((filter) => {
          return <IndividualFilter key={filter.id} filter={filter} />;
        })
      }
      <NewFilterButton cumulative={false} />

    </CollapsiblePanel>
  );
}

export default CompletionUrl;
