import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {minValidation} from '../../NumberValidations';

SDKHeightOption.propTypes = {
  updateFunction: PropTypes.func.isRequired,
  options: PropTypes.object.isRequired,
};

/**
 * The SDK height option
 *
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function SDKHeightOption(props) {
  return (
    <div className='sidebar-option-row'>
      <label
        className='sidebar-label'
        htmlFor='sdk_widget_height_text_field'
      >
        SDK Widget Height:
      </label>

      <NumberFormat
        id='sdk_widget_height_text_field'
        value={props.options.sdkWidgetHeight}
        isAllowed={(values) => {
          return minValidation(values, 0);
        }}
        onBlur={(e) => props.updateFunction({sdkWidgetHeight: e.target.value})}
      />
    </div>
  );
}

export default SDKHeightOption;
