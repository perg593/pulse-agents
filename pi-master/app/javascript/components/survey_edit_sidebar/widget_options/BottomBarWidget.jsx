import React from 'react';
import PropTypes from 'prop-types';

import SDKHeightOption from './SDKHeightOption';

BottomBarWidget.propTypes = {
  updateFormattingOption: PropTypes.func.isRequired,
  formattingOptions: PropTypes.object.isRequired,
};

/**
 * Options specific to bottom bar widgets
 *
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function BottomBarWidget(props) {
  return (
    <SDKHeightOption
      options={props.formattingOptions}
      updateFunction={props.updateFormattingOption}
    />
  );
}

export default BottomBarWidget;
