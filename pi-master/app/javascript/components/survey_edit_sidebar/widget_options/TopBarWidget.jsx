import React from 'react';
import PropTypes from 'prop-types';

import SDKHeightOption from './SDKHeightOption';

TopBarWidget.propTypes = {
  updateFormattingOption: PropTypes.func.isRequired,
  formattingOptions: PropTypes.object.isRequired,
};

/**
 * Options specific to top bar widgets
 *
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function TopBarWidget(props) {
  return (
    <>
      {
        // <div className='sidebar-option-row horizontal'>
        //   <input
        //     id='pusher_enabled'
        //     type='checkbox'
        //     onChange={(e) => props.updateFormattingOption({
        //       pusherEnabled: e.target.checked,
        //     })}
        //     checked={props.formattingOptions.pusherEnabled}
        //   />
        //   <label
        //     className='sidebar-label'
        //     htmlFor='pusher_enabled'
        //   >
        //     Pusher enabled
        //   </label>
        // </div>
      }
      <SDKHeightOption
        options={props.formattingOptions}
        updateFunction={props.updateFormattingOption}
      />
    </>
  );
}

export default TopBarWidget;
