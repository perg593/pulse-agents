import React from 'react';
import PropTypes from 'prop-types';

import OptionsForSelect from './OptionsForSelect';

SurveyStatusSelector.propTypes = {
  allowSurveyStatusChange: PropTypes.bool.isRequired,
  onSelectionChanged: PropTypes.func.isRequired,
  status: PropTypes.string.isRequired,
  statusOptions: PropTypes.array.isRequired,
};

/**
 * A GUI to submit survey status changes
 *
 * @param { object } props - see propTypes
 * @return {JSX.Element}
 **/
function SurveyStatusSelector(props) {
  /**
   * Convert a string to title case
   *
   * @param { string } input - a string representing a single word
   * @return { string } a string in title case
   */
  function titleize(input) {
    return `${input[0].toUpperCase()}${input.slice(1)}`;
  }

  if (props.allowSurveyStatusChange) {
    return (
      <select
        value={props.status}
        onChange={(e) => props.onSelectionChanged(e)}
      >
        <OptionsForSelect options={props.statusOptions} />
      </select>
    );
  } else {
    return <span>{titleize(props.status)}</span>;
  }
}

export default SurveyStatusSelector;
