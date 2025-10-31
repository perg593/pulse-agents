import React from 'react';
import PropTypes from 'prop-types';
import DebouncedInput from '../../../../components/DebouncedInput';

AuthenticationConfig.propTypes = {
  authentication: PropTypes.shape({
    type: PropTypes.oneOf(['none', 'basic', 'form']),
    username: PropTypes.string,
    password: PropTypes.string,
    form_selectors: PropTypes.shape({
      username_selector: PropTypes.string,
      password_selector: PropTypes.string,
      submit_selector: PropTypes.string,
    }),
  }),
  onAuthenticationChange: PropTypes.func.isRequired,
};

/**
 * Component for configuring authentication settings.
 * @param {Object} props - see propTypes
 * @return {JSX.Element}
 */
function AuthenticationConfig(props) {
  const {authentication = {}, onAuthenticationChange} = props;

  /**
   * Update the authentication configuration.
   * @param {string} key - The authentication config key to update
   * @param {string|Object} value - The new value
   */
  const updateAuthenticationConfig = (key, value) => {
    onAuthenticationChange({
      ...authentication,
      [key]: value,
    });
  };

  /**
   * Update a form selector value.
   * @param {string} key - The form selector key to update
   * @param {string} value - The new selector value
   */
  const updateFormSelector = (key, value) => {
    onAuthenticationChange({
      ...authentication,
      form_selectors: {
        ...authentication.form_selectors,
        [key]: value,
      },
    });
  };

  /**
   * Render the authentication form based on the selected type.
   * @return {JSX.Element|null}
   */
  const renderAuthenticationForm = () => {
    const authType = authentication.type;

    if (authType === 'basic') {
      return (
        <div className="basic-auth-section">
          <div className="auth-input-row">
            <div className="auth-input-group">
              <label htmlFor="auth_username">Username</label>
              <DebouncedInput
                id="auth_username"
                value={authentication.username || ''}
                onChange={(value) => updateAuthenticationConfig('username', value)}
                placeholder="Enter username"
                className="form-control"
              />
            </div>

            <div className="auth-input-group">
              <label htmlFor="auth_password">Password</label>
              <DebouncedInput
                id="auth_password"
                type="password"
                value={authentication.password || ''}
                onChange={(value) => updateAuthenticationConfig('password', value)}
                placeholder="Enter password"
                className="form-control"
              />
            </div>
          </div>
        </div>
      );
    }

    if (authType === 'form') {
      return (
        <div className="form-auth-section">
          <div className="auth-input-row">
            <div className="auth-input-group">
              <label htmlFor="auth_username">Username</label>
              <DebouncedInput
                id="auth_username"
                value={authentication.username || ''}
                onChange={(value) => updateAuthenticationConfig('username', value)}
                placeholder="Enter username"
                className="form-control"
              />
            </div>

            <div className="auth-input-group">
              <label htmlFor="auth_password">Password</label>
              <DebouncedInput
                id="auth_password"
                type="password"
                value={authentication.password || ''}
                onChange={(value) => updateAuthenticationConfig('password', value)}
                placeholder="Enter password"
                className="form-control"
              />
            </div>
          </div>
          <div className="form-selectors-section">
            <h4>Form Selectors</h4>

            <div className="selector-input-row">
              <div className="selector-input-group">
                <label htmlFor="username_selector">Username Field Selector</label>
                <DebouncedInput
                  id="username_selector"
                  value={authentication.form_selectors?.username_selector || ''}
                  onChange={(value) => updateFormSelector('username_selector', value)}
                  placeholder="#username, input[name='user']"
                  className="form-control"
                />
              </div>

              <div className="selector-input-group">
                <label htmlFor="password_selector">Password Field Selector</label>
                <DebouncedInput
                  id="password_selector"
                  value={authentication.form_selectors?.password_selector || ''}
                  onChange={(value) => updateFormSelector('password_selector', value)}
                  placeholder="#password, input[name='pass']"
                  className="form-control"
                />
              </div>
            </div>

            <div className="selector-input-row">
              <div className="selector-input-group">
                <label htmlFor="submit_selector">Submit Button Selector</label>
                <DebouncedInput
                  id="submit_selector"
                  value={authentication.form_selectors?.submit_selector || ''}
                  onChange={(value) => updateFormSelector('submit_selector', value)}
                  placeholder="button[type='submit'], .login-btn"
                  className="form-control"
                />
              </div>
            </div>
          </div>
        </div>
      );
    }

    return null;
  };

  return (
    <div className="form-group">
      <hr/>

      <label>Authentication (Optional)</label>

      <p className="hint">
        Configure authentication if the target site requires login.
      </p>

      <div className="controls">
        <div className="auth-type-section">
          <label htmlFor="auth_type">Authentication Type</label>
          <select
            id="auth_type"
            value={authentication.type || 'none'}
            onChange={(e) => updateAuthenticationConfig('type', e.target.value)}
            className="form-control"
          >
            <option value="none">None</option>
            <option value="basic">HTTP Basic Authentication</option>
            <option value="form">HTML Login Form</option>
          </select>
        </div>

        {renderAuthenticationForm()}
      </div>
    </div>
  );
}

export default AuthenticationConfig;
