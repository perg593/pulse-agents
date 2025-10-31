import React from 'react';
import PropTypes from 'prop-types';

const SamlLogin = (props) => {
  return (
    <form action={props.formUrl}>
      <h1 className='form-title'>Single Sign-On</h1>

      <input
        type='hidden'
        name='authenticity_token'
        value={props.authenticityToken}
      />

      <input
        className='full-width-input'
        type='email'
        name='email'
        placeholder='E-mail address'
        required
      />

      <div className='form-action'>
        <input type='submit' value='Sign In'></input>
      </div>

      <a href={props.signinUrl}>Sign in with your Pulse Insights account</a>
    </form>
  );
};

SamlLogin.propTypes = {
  authenticityToken: PropTypes.string.isRequired,
  formUrl: PropTypes.string.isRequired,
  signinUrl: PropTypes.string.isRequired,
};

export default SamlLogin;
