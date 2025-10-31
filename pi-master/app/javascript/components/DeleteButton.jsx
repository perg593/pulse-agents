import React from 'react';
import PropTypes from 'prop-types';

import DeleteIcon from '../images/survey_editor/delete.svg';

DeleteButton.propTypes = {
  onClick: PropTypes.func.isRequired,
};

/**
 * Renders a delete button with a lovely svg mask
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function DeleteButton(props) {
  return (
    <button
      type='button'
      className='delete-control'
      onClick={props.onClick}
      style={{
        maskImage: `url(${DeleteIcon})`,
        WebkitMaskImage: `url(${DeleteIcon})`,
      }}
    />
  );
}

export default DeleteButton;
