import React from 'react';
import PropTypes from 'prop-types';

PIOption.propTypes = {
  // {label: "string or number", value: "string or number"}
  option: PropTypes.object.isRequired,
};

/**
 * Render an option for a select tag
 * @param {props} props - (see propTypes)
 * @return {JSX.Element}
*/
function PIOption(props) {
  return (
    <option value={props.option.value}>
      {props.option.label}
    </option>
  );
};

export default PIOption;
