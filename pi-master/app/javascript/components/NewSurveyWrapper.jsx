import React from 'react';
import PropTypes from 'prop-types';

import {ErrorBoundary} from 'react-error-boundary';

import NumberFormat from 'react-number-format';
import {minValidation} from './NumberValidations';

import ErrorFallback from './ErrorFallback';

NewSurveyWrapper.propTypes = {
  url: PropTypes.string.isRequired, // See NewSurveyForm
  survey: PropTypes.object.isRequired, // See NewSurveyForm
  authenticityToken: PropTypes.string.isRequired, // See NewSurveyForm
};

/**
 * A wrapper component for the new survey form
 * @param { Object } props -- see PropTypes
 * @return { JSX.Element }
*/
function NewSurveyWrapper(props) {
  return (
    <ErrorBoundary
      FallbackComponent={ErrorFallback}
    >
      <NewSurveyForm
        survey={props.survey}
        authenticityToken={props.authenticityToken}
        url={props.url}
      />
    </ErrorBoundary>
  );
}

NewSurveyForm.propTypes = {
  url: PropTypes.string.isRequired, // The URL to submit the form to
  survey: PropTypes.object.isRequired, // The survey object. See backend
  authenticityToken: PropTypes.string.isRequired, // The form authenticity token
};

/**
 * The new survey form
 * @param { Object } props -- see PropTypes
 * @return { JSX.Element }
 */
function NewSurveyForm(props) {
  return (
    <>
      <div className='fake-background'></div>
      <div className='modal-dialog fake-modal'>
        <h4 className='settings-modal-title'>Create New Survey</h4>
        <form
          id='survey_form'
          action={props.url}
          method='post'
        >
          <input
            type='hidden'
            name='authenticity_token'
            value={props.authenticityToken}
          />
          <div className='form-row'>
            <label htmlFor='survey_name_field'>Survey Name</label>
            <input
              id='survey_name_field'
              name={props.survey.name.name}
              placeholder='Type name here...'
              required='required'
              title='No pipes "|" allowed'
              pattern="[^|]+"
            />
          </div>

          <div className='form-row'>
            <label htmlFor='survey_goal_field'>Survey Goal</label>
            <NumberFormat
              id='survey_goal_field'
              name={props.survey.goal.name}
              value={props.survey.goal.value}
              thousandSeparator={true}
              allowNegative={false}
              allowLeadingZeros={false}
              decimalSeparator={null}
              isAllowed={(values) => {
                return minValidation(values, 1);
              }}
            />
          </div>

          <button
            className='btn btn-default create-survey-button'
            type='submit'
          >
            Create Survey
          </button>
        </form>
      </div>
    </>
  );
}

export default NewSurveyWrapper;
