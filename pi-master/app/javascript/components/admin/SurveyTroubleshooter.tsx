import React from 'react';

import Otter from './Otter';
import OtterImage from '../../images/otters/otter_wrench.png';

type Condition = {
  satisfied: boolean
  message: string
};

interface ConditionListItemProps {
  condition: Condition
}

/**
 * @param { ConditionProps } props -- see interface above
 * @return { JSX.Element }
*/
function ConditionListItem(props: ConditionListItemProps) {
  let icon = '';

  if (props.condition.satisfied === null) {
    icon = '❔';
  } else if (props.condition.satisfied) {
    icon = '✅';
  } else {
    icon = '❌';
  }

  return (
    <li>
      <span>
        {icon} {props.condition.message}
      </span>
    </li>
  );
}

interface SurveyTroubleshooterProps {
  surveyId: number
  surveyName: string
  deviceUdid: string
  clientUrl: string
  conditions: Array<Condition>
};

/**
 * @param { SurveyTroubleshooterProps } props -- see interface above
 * @return { JSX.Element }
*/
function SurveyTroubleshooter(props: SurveyTroubleshooterProps) {
  return (
    <>
      <h1>Survey Troubleshooter (Will it show?)</h1>

      <h2>
        {
          props.surveyId === undefined ? 'Please provide survey ID' : `${props.surveyName} (${props.surveyId})`
        }
      </h2>

      <Otter image={OtterImage} title="We've got this -- Otto" />

      <form>
        <label htmlFor='survey_id_field'>Survey ID</label>
        <input
          id='survey_id_field'
          type='text'
          name='survey_id'
          placeholder='Survey ID'
          defaultValue={props.surveyId}
          required
        />

        <label htmlFor='device_udid_field'>Device UDID</label>
        <input
          id='device_udid_field'
          type='text'
          name='device_udid'
          placeholder='Device UDID'
          defaultValue={props.deviceUdid}
        />

        <label htmlFor='url_field'>URL</label>
        <input
          id='url_field'
          type='text'
          name='url'
          placeholder='URL for survey'
          defaultValue={props.clientUrl}
        />

        <input
          className='pi-primary-button'
          type='submit'
          value='Check Survey'
        />
      </form>

      <ul className='condition-list'>
        {
          props.conditions?.map((condition, i) => {
            return <ConditionListItem key={i} condition={condition} />;
          })
        }
      </ul>
    </>
  );
}

export default SurveyTroubleshooter;
