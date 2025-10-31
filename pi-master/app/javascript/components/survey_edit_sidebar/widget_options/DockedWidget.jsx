import React from 'react';
import PropTypes from 'prop-types';

DockedWidget.propTypes = {
  updateFormattingOption: PropTypes.func.isRequired,
  formattingOptions: PropTypes.object.isRequired,
};

/**
 * Options specific to docked widgets
 *
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function DockedWidget(props) {
  return (
    <>
      <div className='sidebar-option-row horizontal'>
        <input
          id='position_content_text_field'
          className='number-input'
          defaultValue={props.formattingOptions.positionContent}
          onBlur={(e) => props.updateFormattingOption({
            positionContent: e.target.value,
          })}
          placeholder='px or %'
        />
        <span>from</span>
        <select
          id='position_type_selector'
          className='position-type-horizontal'
          value={props.formattingOptions.positionType}
          onChange={(e) => props.updateFormattingOption({
            positionType: e.target.value,
          })}
        >
          <option value='right_position'>
            Right Browser Edge
          </option>
          <option value='left_position'>
            Left Browser Edge
          </option>
        </select>
      </div>
    </>
  );
}

export default DockedWidget;
