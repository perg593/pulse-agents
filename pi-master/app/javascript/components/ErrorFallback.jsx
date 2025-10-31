import React from 'react';
import PropTypes from 'prop-types';

// see https://www.npmjs.com/package/react-error-boundary#errorboundary-props
ErrorFallback.propTypes = {
  error: PropTypes.object,
  resetErrorBoundary: PropTypes.func,
};

/**
 * A fallback to render when everything breaks
 * @param { Object } props - see propTypes above
 *
 * @return { JSX.Element } An element to render when everything breaks
 */
function ErrorFallback(props) {
  return (
    <div className="error-fallback-container">
      <p>
        We're sorry, but something went wrong.<br/>
        The development team has been notified.
      </p>
    </div>
  );
}

export default ErrorFallback;
