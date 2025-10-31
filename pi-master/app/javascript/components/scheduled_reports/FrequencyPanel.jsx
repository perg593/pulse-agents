import React from 'react';
import PropTypes from 'prop-types';

import DatePicker from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';

import {isBefore, isSameDay} from 'date-fns';

import OptionsForSelect from '../OptionsForSelect.jsx';
import PanelTemplate from './PanelTemplate.jsx';

const FrequencyPanel = (props) => {
  const [startDate, setStartDate] = React.useState(props.startDate);
  const [endDate, setEndDate] = React.useState(props.endDate);

  // Prevents start times in the past
  const timeConstraints = () => {
    let minTime = null;
    let maxTime = null;

    const curTime = new Date();

    if (isBefore(startDate, curTime) || isSameDay(curTime, startDate)) {
      minTime = curTime;

      maxTime = curTime;
      maxTime.setHours(23);
      maxTime.setMinutes(59);
    }

    return {
      minTime: minTime,
      maxTime: maxTime,
    };
  };

  const sharedDatepickerSettings = {
    minDate: new Date(),
    showTimeSelect: true,
    excludeOutOfBoundsTimes: true,
    dateFormat: 'MMMM d, yyyy h:mm aa z',
    isClearable: true,
  };

  return (
    <PanelTemplate title='Frequency & Timing'>
      <div className='form-row'>
        <label className='form-label'>Frequency</label>
        <select
          name='scheduled_report[frequency]'
          defaultValue={props.frequency}
        >
          <OptionsForSelect options={props.frequencyOptions} />
        </select>
      </div>

      <div className='form-row date-settings-container'>
        <label className='form-label'>Dates</label>

        <DatePicker
          {...sharedDatepickerSettings}
          {...timeConstraints()}
          selected={startDate}
          onChange={(date) => setStartDate(date)}
          placeholderText='Start Immediately'
          name='scheduled_report[start_date]'
        />

        <span>to</span>

        <DatePicker
          {...sharedDatepickerSettings}
          selected={endDate}
          onChange={(date) => setEndDate(date)}
          placeholderText='No End Date'
          name='scheduled_report[end_date]'
        />
      </div>
    </PanelTemplate>
  );
};

FrequencyPanel.propTypes = {
  frequency: PropTypes.string,
  frequencyOptions: PropTypes.array.isRequired,
  startDate: PropTypes.number,
  endDate: PropTypes.number,
};

export default FrequencyPanel;
