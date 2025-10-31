import React from 'react';

/**
 * Render this in a form to prevent "Enter" from submitting the form.
 *
 * @return { JSX.Element } an input element
 **/
function DummyFormSubmitButton() {
  return (
    <input
      type='submit'
      disabled
      style={{display: 'none'}}
    />
  );
}

export default DummyFormSubmitButton;
