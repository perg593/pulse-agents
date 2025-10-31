import React from 'react';
import PropTypes from 'prop-types';

import OutsideClickHandler from 'react-outside-click-handler';

EditableField.propTypes = {
  initialValue: PropTypes.string.isRequired,
  persistentUpdate: PropTypes.func.isRequired,
};

/**
 * A component for editable field
 * @param { Object } props -- see PropTypes
 * @return { JSX.Element }
*/
function EditableField(props) {
  const initialValue = props.initialValue;
  const [value, setValue] = React.useState(initialValue);
  const [editing, setEditing] = React.useState(false);

  const onKeyDown = (e) => {
    if (e.key === 'Escape') {
      toggleField();
    } else if (e.key === 'Enter') {
      const newValue = e.target.value;

      props.persistentUpdate(newValue);
      setValue(newValue);
      toggleField();
    }
  };

  const toggleField = () => {
    setEditing(!editing);
  };

  /**
   * The input component when the field is being edited
   * @return { JSX.Element } the field
   **/
  function Editable() {
    return (
      <OutsideClickHandler onOutsideClick={toggleField} >
        <input
          className='edit-mode-input'
          defaultValue={value}
          onKeyDown={onKeyDown}
        />
      </OutsideClickHandler>
    );
  }

  /**
   * The display component when the field is not being edited
   * @return { JSX.Element } the field
   **/
  function Readonly() {
    return (
      <span className='read-only-container' onClick={toggleField}>
        {value}
      </span>
    );
  }

  return editing ? <Editable /> : <Readonly />;
}

export default EditableField;
