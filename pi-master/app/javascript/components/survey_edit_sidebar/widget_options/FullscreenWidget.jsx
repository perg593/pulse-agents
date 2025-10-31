import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation, maxValidation} from '../../NumberValidations';

FullscreenWidget.propTypes = {
  updateFormattingOption: PropTypes.func.isRequired,
  formattingOptions: PropTypes.object.isRequired,
};

/**
 * Options specific to bottom bar widgets
 *
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function FullscreenWidget(props) {
  return (
    <div className='sidebar-option-row'>
      <label
        className='sidebar-label'
        htmlFor='fullscreen_margin_text_field'
      >
        Margin:
      </label>
      <NumberFormat
        id='fullscreen_margin_text_field'
        className='number-input'
        value={props.formattingOptions.fullscreenMargin}
        isAllowed={(values) => {
          return minValidation(values, 0) && maxValidation(values, 100);
        }}
        onBlur={(e) => props.updateFormattingOption({
          fullscreenMargin: e.target.value,
        })}
      />
    </div>
  );
}

export default FullscreenWidget;
