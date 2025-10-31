import React from 'react';
import PropTypes from 'prop-types';

import DatePicker from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';

const CreationDatePicker = () => {
  const maxDate = () => {
    const tmp = new Date();
    tmp.setDate(tmp.getDate() - 1);

    return tmp;
  };

  const [startDate, setStartDate] = React.useState(maxDate());
  const [endDate, setEndDate] = React.useState(maxDate());
  const onChange = (dates) => {
    const [start, end] = dates;
    setStartDate(start);
    setEndDate(end);
  };

  return (
    <div className='datepicker-wrapper'>
      <h2>Date Range</h2>
      <DatePicker
        selected={startDate}
        onChange={onChange}
        startDate={startDate}
        endDate={endDate}
        maxDate={maxDate()}
        selectsRange
        inline
      />
      <input type='hidden' name='start_date' value={startDate || ''} />
      <input type='hidden' name='end_date' value={endDate || ''} />
    </div>
  );
};

export default CreationDatePicker;
