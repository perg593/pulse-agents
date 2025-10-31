import React from 'react';
import PropTypes from 'prop-types';

import PIOption from './PIOption';

OptionsForSelect.propTypes = {
  // [{label: "string or number", value: "string or number"},...]
  options: PropTypes.array.isRequired,
};

/**
 * Render an array of PIOptions
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
*/
function OptionsForSelect(props) {
  return props.options.map((option) => {
    return <PIOption key={option.value} option={option} />;
  });
};

export default OptionsForSelect;
