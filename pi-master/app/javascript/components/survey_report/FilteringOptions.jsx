import React from 'react';
import PropTypes from 'prop-types';

import Dates from './filtering_options/Dates';
import Devices from './filtering_options/Devices';
import Markets from './filtering_options/Markets';
import CompletionUrl from './filtering_options/CompletionUrl';
import PageviewCount from './filtering_options/PageviewCount';
import VisitCount from './filtering_options/VisitCount';

import * as FilterGenie from './FilterGenie';

const FilteringOptions = (props) => {
  const invalidHeaderMessage = 'Action Required';

  const buttonLabel = () => {
    return props.filterGenie.anyFiltersApplied() ? 'Apply Filter(s)' : 'Select Filters';
  };

  /**
   * Determines whether we can submit the filters
   * @return {bool} whether we can submit them
   */
  function canSubmit() {
    return props.filterGenie.allValid() &&
      props.filterGenie.anyFiltersApplied();
  }

  /**
   * Adds selected filters to query parameters and reloads page
   * Note that we only want to update history _once_
   */
  function applyFilters() {
    window.history.pushState({}, '', props.filterGenie.generateQueryParams());
    window.location.reload(true);
  }

  return (
    <>
      <Dates
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        updateFunction={(newValues) => {
          props.updateSelectedFilters(FilterGenie.FILTER_DATE, newValues);
        }}
        dateRange={props.filterGenie.selectedFilters.dateRangeFilters}
      />
      {
        props.filterGenie.marketFilterAvailable ?
          <Markets
            panelExpansionSettings={props.panelExpansionSettings}
            updatePanelExpansionSettings={props.updatePanelExpansionSettings}
            updateFunction={(newValues) => {
              props.updateSelectedFilters(FilterGenie.FILTER_MARKET, newValues);
            }}
            marketFilters={props.filterGenie.selectedFilters.marketFilters}
            availableMarkets={props.availableMarkets}
            valid={props.filterGenie.filterValid(FilterGenie.FILTER_MARKET)}
            invalidHeaderMessage={invalidHeaderMessage}
          />: null
      }
      <Devices
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        deviceFilters={props.filterGenie.selectedFilters.deviceFilters}
        updateFunction={(newValues) => {
          props.updateSelectedFilters(FilterGenie.FILTER_DEVICE, newValues);
        }}
        valid={props.filterGenie.filterValid(FilterGenie.FILTER_DEVICE)}
        invalidHeaderMessage={invalidHeaderMessage}
      />
      <CompletionUrl
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        completionUrlFilters={props.filterGenie.selectedFilters.completionUrlFilters}
        updateFunction={(newValues) => {
          props.updateSelectedFilters(FilterGenie.FILTER_COMPLETION_URL, newValues);
        }}
        completionUrlMatchers={props.completionUrlMatchers}
        valid={props.filterGenie.filterValid(FilterGenie.FILTER_COMPLETION_URL)}
        invalidHeaderMessage={invalidHeaderMessage}
      />
      <PageviewCount
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        pageviewCountFilter={props.filterGenie.selectedFilters.pageviewCountFilter}
        updateFunction={(newValues) => {
          props.updateSelectedFilters(FilterGenie.FILTER_PAGEVIEW_COUNT, newValues);
        }}
        // TODO: evaluate meaning of validity for this filter
        valid={props.filterGenie.filterValid(FilterGenie.FILTER_PAGEVIEW_COUNT)}
        invalidHeaderMessage={invalidHeaderMessage}
        comparators={props.comparators}
      />
      <VisitCount
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        visitCountFilter={props.filterGenie.selectedFilters.visitCountFilter}
        updateFunction={(newValues) => {
          props.updateSelectedFilters(FilterGenie.FILTER_VISIT_COUNT, newValues);
        }}
        // TODO: evaluate meaning of validity for this filter
        valid={props.filterGenie.filterValid(FilterGenie.FILTER_VISIT_COUNT)}
        invalidHeaderMessage={invalidHeaderMessage}
        comparators={props.comparators}
      />
      <div className='sidebar-option-row'>
        <button
          className='filter-button'
          onClick={() => applyFilters()}
          disabled={!canSubmit()}
        >
          {buttonLabel()}
        </button>
      </div>
    </>
  );
};

FilteringOptions.propTypes = {
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
  updateSelectedFilters: PropTypes.func.isRequired,
  availableMarkets: PropTypes.array,
  filterGenie: PropTypes.instanceOf(FilterGenie.FilterGenie).isRequired,
  completionUrlMatchers: PropTypes.array.isRequired,
  comparators: PropTypes.array.isRequired,
};

export default FilteringOptions;
