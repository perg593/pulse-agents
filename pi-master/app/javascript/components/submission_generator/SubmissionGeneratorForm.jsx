import React from 'react';
import PropTypes from 'prop-types';

import CompletionUrlSection from './CompletionUrlSection';
import CreationDatePicker from './CreationDatePicker';
import Question from './Question';

SubmissionGeneratorForm.propTypes = {
  authenticityToken: PropTypes.string.isRequired,
  formUrl: PropTypes.string.isRequired,
  questionLookupUrl: PropTypes.string.isRequired,
};

/**
 * A form for generating submission records
 * @param { Object } props - see propTypes above
 *
 * @return { JSX.Element } The form
 */
function SubmissionGeneratorForm(props) {
  const [questions, setQuestions] = React.useState([]);

  /**
   * Validate the user provided survey ID
   * @param { Element } field - A reference to the survey ID input field
   */
  function validateSurveyId(field) {
    if (field.validity.patternMismatch) {
      field.setCustomValidity('I\'m expecting a number!');
      field.reportValidity();
    } else {
      field.setCustomValidity('');
    }
  }

  /**
   * Fetch question data from server
   * @param { number } surveyId - The survey whose questions we'd like
   */
  function fetchQuestionData(surveyId) {
    $.ajax({
      url: props.questionLookupUrl,
      method: 'GET',
      data: {survey_id: surveyId},
    }).done(function(response) {
      setQuestions(response.questions);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('error finding survey');
    });
  }

  return (
    <form
      id='scheduled_report_form'
      action={props.formUrl}
      method='POST'
    >
      <input
        type='hidden'
        name='authenticity_token'
        value={props.authenticityToken}
      />

      <div className='input-row'>
        <label htmlFor='survey_id_field'>Survey ID:</label>
        <input
          id='survey_id_field'
          name='survey_id'
          required
          inputMode='numeric'
          pattern='\d*'
          onChange={(e) => {
            const field = e.target;
            validateSurveyId(field);
          }}
          onBlur={(e) => {
            const field = e.target;

            if (!field.checkValidity()) {
              return;
            }

            const surveyId = field.value;
            fetchQuestionData(surveyId);
          }}
        />
      </div>

      <div className='input-row'>
        <label htmlFor='num_impressions_to_create_field'>
          Number of impressions:
        </label>
        <input
          id='num_impressions_to_create_field'
          name='num_impressions_to_create'
          type='number'
          min={1}
        />
      </div>

      <div className='input-row'>
        <label htmlFor='num_viewed_impressions_to_create_field'>
          Number of Viewed Impressions:
        </label>
        <input
          id='num_viewed_impressions_to_create_field'
          name='num_viewed_impressions_to_create'
          type='number'
          min={1}
        />
      </div>

      <div className='input-row'>
        <label htmlFor='num_submissions_to_create_field'>
          Number of submissions:
        </label>
        <input
          id='num_submissions_to_create_field'
          name='num_submissions_to_create'
          type='number'
          min={0}
        />
      </div>

      <CompletionUrlSection />

      <CreationDatePicker />

      {
        questions.map((question) => {
          return <Question key={question.id} question={question} />;
        })
      }

      <button
        className='btn btn-default generate-submissions-button'
        type='submit'
      >
        Generate Samples
      </button>
    </form>
  );
}

export default SubmissionGeneratorForm;
