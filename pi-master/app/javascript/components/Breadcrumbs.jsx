import React from 'react';
import PropTypes from 'prop-types';

import {EditableField} from './survey_editor/EditableField';
import SurveyStatusSelector from './SurveyStatusSelector';

Breadcrumbs.propTypes = {
  allowSurveyNameChange: PropTypes.bool.isRequired,
  allowSurveyStatusChange: PropTypes.bool.isRequired,
  surveyName: PropTypes.string.isRequired,
  surveyId: PropTypes.number.isRequired,
  surveyStatus: PropTypes.string.isRequired,
  surveyStatusOptions: PropTypes.array.isRequired,
  surveyLocaleGroupName: PropTypes.string,
};

/**
 * Interactive survey breadcrumbs
 * @param { object } props - see propTypes
 * @return { JSX.Element }
*/
function Breadcrumbs(props) {
  const [surveyStatus, setSurveyStatus] = React.useState(props.surveyStatus);
  const [surveyName, setSurveyName] = React.useState(props.surveyName);

  /**
   * Handle survey status selection
   * @param { InputEvent } e - selection changed
  */
  function onSelectionChanged(e) {
    const newValue = e.target.value;

    const warningMessage = 'Are you sure you want to set this survey Live? Press "OK" to proceed.';

    if (newValue !== 'live' || window.confirm(warningMessage)) {
      inlineEdit('status', newValue, () => setSurveyStatus(newValue));
    }
  }

  /**
   * AJAX call to handle survey attribute change
   *
   * @param { string } key - the survey attribute
   * @param { string } value - the new value
   * @param { function } onDone - run after a successful update
  */
  function inlineEdit(key, value, onDone) {
    const payload = {survey: {}};
    payload.survey[key] = value;

    $.ajax({
      url: `/surveys/${props.surveyId}/inline_edit`,
      method: 'POST',
      data: payload,
    }).done(function(_response) {
      onDone();
      console.debug('update successful!');
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('error updating record', jqXHR, textStatus, errorThrown);
    });
  }

  /**
   * A field for the survey name
   * May be editable
   *
   * @return { JSX.Element } The field
   **/
  function SurveyNameField() {
    if (props.allowSurveyNameChange) {
      return (
        <EditableField
          placeholderTagName='span'
          placeholderText={'Enter a survey name'}
          initialContent={props.surveyName}
          inputContext='[survey][name]'
          inputClass='inline-edit-survey-name-input'
          onUpdate={(newValue) => {
            if (newValue.trim() !== '' && surveyName != newValue) {
              inlineEdit('name', newValue, () => setSurveyName(newValue));
            }
          }}
        />
      );
    } else {
      return <span>{props.surveyName}</span>;
    }
  }

  return (
    <div className='navbar-breadcrumbs-container'>
      {
        props.surveyLocaleGroupName ?
          <>
            <span>{props.surveyLocaleGroupName}</span>
            <span>&gt;</span>
          </> :
            null
      }

      <SurveyNameField />

      <SurveyStatusSelector
        allowSurveyStatusChange={props.allowSurveyStatusChange}
        onSelectionChanged={(e) => onSelectionChanged(e)}
        status={surveyStatus}
        statusOptions={props.surveyStatusOptions}
      />
    </div>
  );
}

export default Breadcrumbs;
