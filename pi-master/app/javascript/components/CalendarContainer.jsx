import React from 'react';
import PropTypes from 'prop-types';

import {parse, format} from 'date-fns';
import {CalendarContainer} from 'react-datepicker';

/**
 * A custom input for react-datepicker
 * NOTE: This must be a class component. See
 * https://github.com/Hacker0x01/react-datepicker/issues/862 for details.
 **/
class CustomDatePickerInput extends React.Component {
  /**
   * Provides custom input for react-datepicker
   * @param {Object} props - contains node model data and an engine reference
   **/
  constructor(props) {
    super(props);
  }

  /**
   * Render CustomDatePickerInput
   * @return {JSX.Element}
   **/
  render() {
    return (
      <input
        onClick={this.props.onClick}
        placeholder={this.props.placeholderText}
      />
    );
  }
}
CustomDatePickerInput.propTypes = {
  onClick: PropTypes.func,
  placeholderText: PropTypes.string,
};

const CustomCalendarContainer = (props) => {
  const CalendarOption = ({action, label}) => {
    return (
      <li>
        <button onClick={action}>
          {label}
        </button>
      </li>
    );
  };
  CalendarOption.propTypes = {
    action: PropTypes.func.isRequired,
    label: PropTypes.string.isRequired,
  };

  const setDaysAgo = (daysAgo) => {
    const newStartDate = new Date();
    newStartDate.setDate(newStartDate.getDate() - daysAgo);

    // midnight. hours, minutes, seconds, ms
    newStartDate.setHours(0, 0, 0, 0);

    // end of day
    const newEndDate = new Date();
    newEndDate.setDate(newEndDate.getDate() - daysAgo);
    newEndDate.setHours(23, 59, 59, 999);

    return [newStartDate, newEndDate];
  };

  const setRangeAgo = (daysAgo) => {
    const newStartDate = new Date();
    newStartDate.setDate(newStartDate.getDate() - daysAgo);

    const newEndDate = new Date();

    return [newStartDate, newEndDate];
  };

  return (
    <div className="calendar-container">
      <CalendarContainer className={props.className}>
        <div className="calendar-side-panel">
          <ul>
            <CalendarOption
              action={() => props.updateDates(...setDaysAgo(1))}
              label='Yesterday'
            />
            <CalendarOption
              action={() => props.updateDates(...setRangeAgo(7))}
              label='Last 7 days' />
            <CalendarOption
              action={() => props.updateDates(...setRangeAgo(30))}
              label='Last 30 days'
            />
            <CalendarOption
              action={() => props.clearFilter()}
              label='All-time'
            />
          </ul>
        </div>
        <div style={{position: 'relative'}}>{props.children}</div>
      </CalendarContainer>
    </div>
  );
};
CustomCalendarContainer.propTypes = {
  className: PropTypes.string,
  children: PropTypes.node,
  updateDates: PropTypes.func,
  clearFilter: PropTypes.func,
};

/**
 * Generates placeholdertext for a date input field
 *
 * @param {Date} startDate
 * @param {Date} endDate
 * @return {string} - placeholder text
 */
function customInputPlaceholderText(startDate, endDate) {
  const startDateLabel = startDate ? startDate.toDateString() : '';
  const endDateLabel = endDate ? `- ${endDate.toDateString()}` : '';

  return `${startDateLabel}${endDateLabel}` || 'All-time';
};

/**
 * Takes a Date in one zone and interprets it in your local zone
 *
 * @param {Date} date - The date to interpret in your local zone
 *
 * @return {Date} The new date, which will have your local zone applied
 **/
function dateWithoutZone(date) {
  return new Date(
      date.getFullYear(),
      date.getMonth(),
      date.getDate(),
      date.getHours(),
      date.getMinutes(),
      date.getSeconds(),
  );
}

// Produces an ISO 8601 datetime
const formatString = "yyyy-MM-dd'T'HH:mm:ss'Z'";

/**
 * Generates query parameters and adds them to the provided URL
 *
 * @param {Date} startDate
 * @param {Date} endDate
 * @param {URL} url - the URL to modify
 * @return {URL} - the modified URL
 */
function updateDateRangeQueryParams(startDate, endDate, url) {
  [['from', startDate], ['to', endDate]].forEach((dateParams) => {
    const filterContext = dateParams[0];
    let filterValue = dateParams[1];

    url.searchParams.delete(filterContext);

    if (filterValue) {
      filterValue = format(dateWithoutZone(filterValue), formatString);

      url.searchParams.append(filterContext, filterValue);
    }
  });

  return url;
}

/**
 * Retrives date range values from the provided URL's query parameters
 *
 * @param {URL} url - the URL containing the query parameters
 * @return {Array} - [startDate, endDate]
 */
function getDateRangeFromQueryParams(url) {
  let startDate = url.searchParams.get('from');
  let endDate = url.searchParams.get('to');

  if (startDate) {
    startDate = parse(startDate, formatString, new Date());
  }

  if (endDate) {
    endDate = parse(endDate, formatString, new Date());
  }

  return [startDate, endDate];
}

export {
  CustomDatePickerInput, CustomCalendarContainer, customInputPlaceholderText,
  updateDateRangeQueryParams, getDateRangeFromQueryParams,
};
