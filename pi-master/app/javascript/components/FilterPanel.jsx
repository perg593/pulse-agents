import React from 'react';
import PropTypes from 'prop-types';

import CollapseFilterPanel from '../images/survey_dashboard/collapse.svg';
import ExpandFilterPanel from '../images/survey_dashboard/expand.svg';
import MagnifyingGlass from '../images/survey_dashboard/magnifying_glass.svg';

import DatePicker from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';

import ArrowUp from '../images/survey_dashboard/arrow_up.svg';
import ArrowDown from '../images/survey_dashboard/arrow_down.svg';

import {arrayWrap} from './FilterFunctions';

import {
  CustomDatePickerInput, CustomCalendarContainer, customInputPlaceholderText,
  updateDateRangeQueryParams,
} from './CalendarContainer';
import DateRangeDatePickerPanel from './DateRangeDatePickerPanel';

const DatePickerFilterPanel = ({setFilter, filterKey, storedFilter, state}) => {
  let filterArgs = state.filters.find((filter) => filter.id === filterKey)?.value || storedFilter;
  filterArgs = arrayWrap(filterArgs);

  const [dateRange, setInternalDateRange] = React.useState([filterArgs[0] ? new Date(filterArgs[0]) : null, filterArgs[1] ? new Date(filterArgs[1]) : null]);

  const updateDates = (newStartDate, newEndDate) => {
    if (newStartDate && newEndDate) {
      updateDateParams(filterKey, [newStartDate, newEndDate]);
      setFilter(filterKey, [newStartDate, newEndDate]);
      setInternalDateRange([newStartDate, newEndDate]);
    } else {
      setInternalDateRange([newStartDate, null]);
    }
  };

  const setDateRange = (dates) => {
    const [newStartDate, newEndDate] = dates;
    newStartDate.setHours(0, 0, 0, 0);

    if (newEndDate) {
      // just before midnight
      newEndDate.setHours(23, 59, 59, 999);
    }

    updateDates(newStartDate, newEndDate);
  };

  const clearFilter = () => {
    updateDateParams(filterKey, [null, null]);
    setFilter(filterKey, undefined);
    setInternalDateRange([null, null]);
  };

  // We need a wrapper around CustomCalendarContainer, which we then pass to
  // DatePicker, because react-datepicker won't pass our props to the
  // calendarContainer we specify.
  const CalendarContainerPropPassthrough = ({className, children}) => {
    return (
      <CustomCalendarContainer
        className={className}
        children={children}
        updateDates={(newStartDate, newEndDate) => {
          updateDates(newStartDate, newEndDate);
        }}
        clearFilter={() => clearFilter()}
      />
    );
  };

  return (
    <DatePicker
      selected={dateRange[0]}
      startDate={dateRange[0]}
      endDate={dateRange[1]}
      onChange={setDateRange}
      calendarContainer={CalendarContainerPropPassthrough}
      monthsShown={3}
      customInput={
        <CustomDatePickerInput
          placeholderText={customInputPlaceholderText(dateRange[0], dateRange[1])}
        />
      }
      openToDate={dateRange[0] || new Date()}
      shouldCloseOnSelect={dateRange[0] && !dateRange[1]}
      selectsRange
    />
  );
};

DatePickerFilterPanel.propTypes = {
  setFilter: PropTypes.func.isRequired,
  filterKey: PropTypes.string.isRequired,
  storedFilter: PropTypes.array,
  state: PropTypes.object.isRequired,
};

/**
 * A container for a filter that can be expanded and collapsed
 **/
class FilterSubPanel extends React.Component {
  /**
   * Provides custom input for react-datepicker
   * @param {Object} props - contains node model data and an engine reference
   **/
  constructor(props) {
    super(props);

    this.state = {
      expanded: true,
    };
  }

  /**
   * Expand or collapse this panel
   **/
  toggleExpansion() {
    this.setState(
        {
          expanded: !this.state.expanded,
        },
    );
  }

  /**
   * The html class for expansion
   * @return {string} - The html class based on expansion state
   **/
  filterExpansionClass() {
    return this.state.expanded ? 'expanded' : 'collapsed';
  };

  /**
   * Render FilterSubPanel
   * @return {JSX.Element}
   **/
  render() {
    return (
      <div className="filter-sub-panel">
        <div
          className="filter-sub-panel-header"
          onClick={() => {
            this.toggleExpansion();
          }}
        >
          { this.props.header }
          <img
            className="folding-arrow-icon"
            src={ this.state.expanded ? ArrowUp : ArrowDown }
          ></img>
        </div>
        <div
          className={`filter-sub-panel-contents ${this.filterExpansionClass()}`}
        >
          { this.props.children }
        </div>
      </div>
    );
  };
}
FilterSubPanel.propTypes = {
  onClick: PropTypes.func,
  children: PropTypes.node.isRequired,
  header: PropTypes.string.isRequired,
};

const updateDateParams = (columnId, dateRange) => {
  const filterContext = `filters[${columnId}][]`;
  const url = new URL(window.location);

  url.searchParams.delete(filterContext);

  dateRange.forEach((date) => {
    if (date) {
      url.searchParams.append(filterContext, date);
    }
  });

  window.history.pushState({}, '', url);
};

const updateFreeTextParams = (columnId, filterValue) => {
  const filterContext = `filters[${columnId}]`;
  const url = new URL(window.location);

  url.searchParams.delete(filterContext);

  if (filterValue) {
    url.searchParams.append(filterContext, filterValue);
  }

  window.history.pushState({}, '', url);
};

const updateCheckboxParams = (columnId, filterActive, filterValue) => {
  const filterContext = `filters[${columnId}][]`;

  const url = new URL(window.location);

  const searchParams = new URLSearchParams(window.location.search);
  const statusFilterParams = searchParams.getAll(filterContext) || [];

  if (filterActive) {
    if (!statusFilterParams.includes(filterValue)) {
      url.searchParams.append(filterContext, filterValue);
      window.history.pushState({}, '', url);
    }
  } else {
    url.searchParams.delete(filterContext);

    statusFilterParams.filter((statusFilterParam) => statusFilterParam !== filterValue).forEach((statusFilterParam) => {
      url.searchParams.append(filterContext, statusFilterParam);
    });

    window.history.pushState({}, '', url);
  }
};

/**
 * A container for all filters. It can be expanded and collapsed
 *
 * TODO: Find a more direct way to get tagsLink. Maybe let table state drive
 * these values, rather than letting them track themselves.
 *
 * @return {JSX.Element}
 **/
function FilterPanel(
    {
      tableInstance: { setFilter, columns, state },
      tagsLink, ClearFiltersButton
    }
) {
  const checkbox = ({value, label, initialCheckedState}, columnId) => {
    const runtimeFilter = state.filters.some((filter) => filter.id === columnId && filter.value.includes(value));
    const checked = runtimeFilter != initialCheckedState ? runtimeFilter : initialCheckedState;

    const filterName = `${columnId}Filter`;

    const onChange = (e) => {
      updateCheckboxParams(columnId, e.target.checked, e.target.value);
      setORFilter(e, filterName, columnId);
    };

    return (
      <>
        <input
          type="checkbox"
          value={value}
          id={`${filterName}_${value}`}
          onChange={onChange}
          name={filterName}
          className="survey-filter-checkbox"
          checked={checked}
        />
        <label htmlFor={`${filterName}_${value}`}>
          {label}
        </label>
      </>
    );
  };

  // Here as a reference for potential radio buttons
  // const radioButton = ({value, label}, name, onChange) => {
  //   return (
  //     <div style={{ display: 'flex', alignItems: 'center'}}>
  //       <input
  //         type="radio"
  //         value={value}
  //         id={value}
  //         onChange={onChange}
  //         name={name}
  //         className="survey-filter-radio-button"
  //       />
  //       <label htmlFor={value}>
  //         {label}
  //       </label>
  //     </div>
  //   );
  // }

  const setORFilter = (e, filterName, filterID) => {
    const filterValues = [];

    $(`input[name=${filterName}]`).each(function() {
      const el = $(this);

      if (el.is(':checked')) {
        filterValues.push(el.val());
      }
    });

    if (filterValues.length > 0) {
      setFilter(filterID, filterValues);
    } else {
      setFilter(filterID, undefined);
    }
  };

  // This sets a filter on nameID, but it's applied to all columns defined in
  // fuzzyTextFilter
  const setTextSearchFilter = (e) => {
    const value = e.target.value;

    if (value === '' || value.trim() === '') {
      setFilter('nameID', undefined);
      updateFreeTextParams('nameID', null);
    } else {
      setFilter('nameID', value);
      updateFreeTextParams('nameID', value);
    }
  };

  const [filterPanelExpanded, setFilterPanelExpanded] = React.useState(true);
  const [tagsListExpanded, setTagsListExpanded] = React.useState(false);
  const minNumTagsToShow = 12;

  const toggleTags = (e) => {
    e.preventDefault();
    setTagsListExpanded(!tagsListExpanded);
  };

  const checkboxOptions = (filterColumnId) => {
    return (
      <ul>
        {
          columns.find((column) => {
            return column.id === filterColumnId;
          }).options.map((option)=> {
            return (
              <li key={option.value}>
                { checkbox(option, filterColumnId) }
              </li>
            );
          })
        }
      </ul>
    );
  };

  const filterExpansionClass = () => {
    return filterPanelExpanded ? 'expanded' : 'collapsed';
  };

  return (
    <div
      className={`filter-panel ${filterExpansionClass()}`}
    >
      <div
        className={`filter-tab ${filterExpansionClass()}`}
        onClick={() => {
          setFilterPanelExpanded(!filterPanelExpanded);
        }}
      >
        <img
          className="folding-arrow-icon"
          src={filterPanelExpanded ? CollapseFilterPanel : ExpandFilterPanel}
        ></img>
      </div>

      <div className="filter-sub-panel">
        <div className="filter-sub-panel-contents text-search">
          <input
            placeholder="Search"
            onChange={setTextSearchFilter}
            style={{width: '100%'}}
            defaultValue={
              columns.find((column) => {
                return column.id === 'nameID';
              }).initialFilterValue
            }
          />
          <img className="magnifying-glass-icon" src={ MagnifyingGlass }></img>
        </div>
      </div>

      <FilterSubPanel header="Date Range">
        <DateRangeDatePickerPanel
          updateFunction={([startDate, endDate]) => {
            let url = new URL(window.location);

            url = updateDateRangeQueryParams(startDate, endDate, url);

            window.history.pushState({}, '', url);
            window.location.reload(true);
          }}
        />
      </FilterSubPanel>

      <FilterSubPanel header="Status">
        { checkboxOptions('statusID') }
      </FilterSubPanel>

      <FilterSubPanel header="Tags">
        <ul>
          {
            columns.find(column => column.id === 'tagsID').options.map((option, index) => {
              return (
                <li
                  key={option.value}
                  style={tagsListExpanded || index < minNumTagsToShow ? {} : {display: 'none'}}
                >
                  { checkbox(option, 'tagsID') }
                </li>
              )
            })
          }

          {
            columns.find(column => column.id === 'tagsID').options.length > minNumTagsToShow ?
              <li>
                <a
                  href='#'
                  onClick={(e) => toggleTags(e)}
                >
                  {tagsListExpanded ? 'Show less' : 'Show more'}
                </a>
              </li> :
                null
          }

          <li>
            <a href={tagsLink}>Edit Tags</a>
          </li>
        </ul>
      </FilterSubPanel>

      <FilterSubPanel header="Created By">
        { checkboxOptions('createdByNameID') }
      </FilterSubPanel>

      <FilterSubPanel header="Last Edited By">
        { checkboxOptions('editedByID') }
      </FilterSubPanel>

      <FilterSubPanel header="Last Changed">
        <DatePickerFilterPanel
          setFilter={setFilter}
          filterKey='lastChangeID'
          storedFilter={
            columns.find((column) => {
              return column.id === 'lastChangeID';
            }).initialFilterValue
          }
          state={state}
        />
      </FilterSubPanel>

      <ClearFiltersButton />
    </div>
  );
}

export default FilterPanel;
