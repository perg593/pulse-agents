import React from 'react';
import DatePicker from 'react-datepicker';

import PropTypes from 'prop-types';

import {
  CustomDatePickerInput, CustomCalendarContainer, customInputPlaceholderText,
  getDateRangeFromQueryParams,
} from './CalendarContainer';

const DateRangeDatePickerPanel = (props) => {
  const [dateRange, setDateRange] = React.useState(() => {
    if (props.dateRange && props.dateRange.length == 2) {
      return [...props.dateRange];
    } else {
      const url = new URL(window.location);
      return getDateRangeFromQueryParams(url);
    }
  });

  // non-ajax call to refresh page with date range added to parameters
  // [startDate, endDate]
  const updateRemoteDateRange = (startDate, endDate) => {
    props.updateFunction([startDate, endDate]);
  };

  const pickDateRange = (dates) => {
    const [newStartDate, newEndDate] = dates;

    newStartDate.setHours(0, 0, 0, 0);

    if (newEndDate) {
      // just before midnight
      newEndDate.setHours(23, 59, 59, 999);
      updateRemoteDateRange(newStartDate, newEndDate);
    } else {
      setDateRange([newStartDate, null]);
    }
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
          updateRemoteDateRange(newStartDate, newEndDate);
        }}
        clearFilter={() => updateRemoteDateRange(null, null)}
      />
    );
  };

  const showPreviousMonths = dateRange[0] === null;

  return (
    <DatePicker
      selected={dateRange[0]}
      startDate={dateRange[0]}
      endDate={dateRange[1]}
      onChange={pickDateRange}
      calendarContainer={CalendarContainerPropPassthrough}
      monthsShown={3}
      customInput={
        <CustomDatePickerInput
          placeholderText={customInputPlaceholderText(...dateRange)}
        />
      }
      openToDate={dateRange[0] || new Date()}
      shouldCloseOnSelect={dateRange[0] && !dateRange[1]}
      selectsRange
      popperPlacement={props.placement || 'bottom-start'}
      showPreviousMonths={showPreviousMonths}
      maxDate={showPreviousMonths ? null : new Date()}
    />
  );
};

DateRangeDatePickerPanel.propTypes = {
  updateFunction: PropTypes.func.isRequired,
  dateRange: PropTypes.array,
  placement: PropTypes.string,
};

export default DateRangeDatePickerPanel;
