import React from 'react';
import PropTypes from 'prop-types';

import OptionsForSelect from '../OptionsForSelect.jsx';
import PanelTemplate from './PanelTemplate.jsx';

const DateRangePanel = (props) => {
  return (
    <PanelTemplate title='Report Date Range'>
      <div className='form-row date-range-container'>
        <label className='form-label'>
          Include Data
        </label>
        <select
          name='scheduled_report[date_range]'
          defaultValue={props.dataRange}
        >
          <OptionsForSelect options={props.dateRangeOptions} />
        </select>

        <div className='send-email-container'>
          <input
            name='scheduled_report[send_no_results_email]'
            type='hidden'
            value='false'
          />
          <input
            id='send_no_results_email'
            name='scheduled_report[send_no_results_email]'
            defaultChecked={props.sendNoResultsEmail}
            type='checkbox'
            value='true'
          />
          <label htmlFor='send_no_results_email'>
            Send email when the report has no data
          </label>
        </div>
      </div>
    </PanelTemplate>
  );
};

DateRangePanel.propTypes = {
  dataRange: PropTypes.string,
  dateRangeOptions: PropTypes.array.isRequired,
  sendNoResultsEmail: PropTypes.bool.isRequired,
};

export default DateRangePanel;
