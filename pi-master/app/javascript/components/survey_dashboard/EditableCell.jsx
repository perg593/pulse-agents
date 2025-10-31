import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import OutsideClickHandler from 'react-outside-click-handler';

import SurveyStatusSelector from '../SurveyStatusSelector';

const EditableCell = (
    {
      reactTableProps: {
        value: initialValue,
        row,
        column,
        // A custom function we supplied to our table instance
        persistentUpdate,
        allowSurveyStatusChange,
      },
    },
) => {
  const surveyId = row.original.surveyId || null;
  const surveyLocaleGroupId = row.original.surveyLocaleGroupId || null;
  const columnId = column.id;
  const dbColumnName = column.dbColumnName;

  // We need to keep and update the state of the cell normally
  const [savedValue, setSavedValue] = React.useState(initialValue);
  const [value, setValue] = React.useState(initialValue);
  const [showingInput, setShowInput] = React.useState(false);

  const onChangeSelectTag = (e) => {
    const newValue = e.target.value;
    const confirmationMessage = "Are you sure you want to set this survey Live? Press \"OK\" to proceed.";

    if (newValue === 'live' && !window.confirm(confirmationMessage)) {
      // roll back
      e.target.value = value;
    } else {
      setValue(newValue);
      persistentUpdate(dbColumnName, newValue, surveyId, surveyLocaleGroupId);
    }
  };

  const onChange = (e) => {
    const newValue = e.target.value;

    if (newValue && newValue.length > 0) {
      setValue(newValue);
    }
  };

  // revert to last persistant value
  const abortEdit = () => {
    setValue(savedValue);
    toggleField();
  };

  const onKeyDown = (e) => {
    if (e.key === 'Escape') {
      abortEdit();
    } else if (e.key === 'Enter') {
      persistentUpdate(dbColumnName, value, surveyId, surveyLocaleGroupId);
      setSavedValue(value);
      toggleField();
    }
  };

  // If the initialValue is changed externally, sync it up with our state
  React.useEffect(() => {
    setValue(initialValue);
  }, [initialValue]);

  const toggleField = (e) => {
    setShowInput(!showingInput);
  };

  const textInput = (inputStyles={}, size=null) => {
    if (showingInput) {
      return (
        <OutsideClickHandler onOutsideClick={abortEdit} >
          <input
            size={size}
            style={inputStyles}
            value={value}
            onKeyDown={onKeyDown}
            onChange={onChange}
          />
        </OutsideClickHandler>
      );
    } else {
      return <span onClick={toggleField}>{value}</span>;
    }
  };

  if (columnId === 'statusID') {
    return <SurveyStatusSelector
      allowSurveyStatusChange={allowSurveyStatusChange}
      onSelectionChanged={(e) => onChangeSelectTag(e)}
      status={value}
      statusOptions={column.options}
    />;
  } else if (columnId === 'nameID') {
    const numSurveysInGroup = row.subRows.length;

    const containerClass = `localization-group-name-container
      ${showingInput ? 'editing' : ''}
      ${row.isExpanded ? 'expanded' : ''}
    `;

    return (
      <div className={containerClass}>
        { textInput({width: '100%'}, value.length) }
        {
          numSurveysInGroup > 0 ?
            <span>&nbsp;({numSurveysInGroup})</span> :
              null
        }
      </div>
    );
  } else if (columnId === 'goalID') {
    return (
      showingInput ?
        <OutsideClickHandler onOutsideClick={abortEdit} >
          <NumberFormat
            value={value}
            thousandSeparator={true}
            allowNegative={false}
            allowLeadingZeros={false}
            decimalSeparator={null}
            onChange={onChange}
            onKeyDown={onKeyDown}
            size={Math.max(1, value.replace(/,/gi, '').length)}
          />
        </OutsideClickHandler> :
          <span className='goals-content' onClick={toggleField}>{value}</span>
    );
  } else {
    return textInput();
  }
};

// react-table supplies the parameters
EditableCell.propTypes = {
  params: PropTypes.object,
};

export default EditableCell;
