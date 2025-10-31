import React from 'react';
import PropTypes from 'prop-types';

const CompletionUrlField = (props) => {
  return (
    <>
      <input
        id='survey_id_field'
        name='completion_urls[]'
        className='completion-url-field'
        defaultValue={props.completionUrl}
        onBlur={(e) => {
          const field = e.target;
          props.updateCompletionUrl(props.completionUrl, field.value, field);
        }}
        required
      />
      <button
        type='button'
        className='close'
        onClick={() => {
          props.removeCompletionUrl(props.completionUrl);
        }}
      >
        ×
      </button>
    </>
  );
};

CompletionUrlField.propTypes = {
  completionUrl: PropTypes.string.isRequired,
  updateCompletionUrl: PropTypes.func.isRequired,
  removeCompletionUrl: PropTypes.func.isRequired,
};

export default CompletionUrlField;
