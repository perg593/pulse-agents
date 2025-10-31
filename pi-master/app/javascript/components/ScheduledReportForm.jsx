import React from 'react';
import PropTypes from 'prop-types';

import NamePanel from './scheduled_reports/NamePanel.jsx';
import SurveyListPanel from './scheduled_reports/SurveyListPanel.jsx';
import FrequencyPanel from './scheduled_reports/FrequencyPanel.jsx';
import DateRangePanel from './scheduled_reports/DateRangePanel.jsx';
import RecipientsPanel from './scheduled_reports/RecipientsPanel.jsx';

const ScheduledReportForm = (props) => {
  return (
    <form
      id='scheduled_report_form'
      action={props.formUrl}
      method='POST'
    >
      <input
        type='hidden'
        name='_method'
        value={props.formMethod}
      />
      <input
        type='hidden'
        name='authenticity_token'
        value={props.authenticityToken}
      />

      <NamePanel name={props.name} />
      <SurveyListPanel
        allSurveys={props.allSurveys}
        surveyOptions={props.surveyOptions}
        surveyLocaleGroupOptions={props.surveyLocaleGroupOptions}
      />
      <FrequencyPanel
        frequency={props.frequency}
        frequencyOptions={props.frequencyOptions}
        startDate={props.startDate}
        endDate={props.endDate}
      />
      <DateRangePanel
        dataRange={props.dataRange}
        dateRangeOptions={props.dateRangeOptions}
        sendNoResultsEmail={props.sendNoResultsEmail}
      />
      <RecipientsPanel emailOptions={props.emailOptions} />

      <div className='form-action-container'>
        <button className='btn btn-xs btn-default' type='submit'>Save</button>
      </div>
    </form>
  );
};

ScheduledReportForm.propTypes = {
  authenticityToken: PropTypes.string.isRequired,
  formMethod: PropTypes.string.isRequired,
  formUrl: PropTypes.string.isRequired,

  // see SurveyListPanel
  allSurveys: PropTypes.bool,
  surveyLocaleGroupOptions: PropTypes.array.isRequired,
  surveyOptions: PropTypes.array.isRequired,

  // see NamePanel
  name: PropTypes.string,

  // see DateRangePanel
  dataRange: PropTypes.string,
  dateRangeOptions: PropTypes.array.isRequired, // { label:, value: }
  sendNoResultsEmail: PropTypes.bool.isRequired,

  // see RecipientsPanel
  emailOptions: PropTypes.array.isRequired, // { label:, checked: }

  // see FrequencyPanel
  frequency: PropTypes.string,
  frequencyOptions: PropTypes.array.isRequired, // { label:, value: }
  startDate: PropTypes.number,
  endDate: PropTypes.number,
};

export default ScheduledReportForm;
