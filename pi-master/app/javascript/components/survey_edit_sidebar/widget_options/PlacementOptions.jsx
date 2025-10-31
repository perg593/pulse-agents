import React from 'react';
import PropTypes from 'prop-types';

import DockedWidget from './DockedWidget';
import InlineWidget from './InlineWidget';
import TopBarWidget from './TopBarWidget';
import BottomBarWidget from './BottomBarWidget';
import FullscreenWidget from './FullscreenWidget';

PlacementOptions.propTypes = {
  updateFormattingOption: PropTypes.func.isRequired,
  formattingOptions: PropTypes.object.isRequired,
};

/**
 * The survey widget placement options
 *
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function PlacementOptions(props) {
  switch (props.formattingOptions.surveyType) {
    case 'docked_widget':
      return <DockedWidget
        updateFormattingOption={props.updateFormattingOption}
        formattingOptions={props.formattingOptions}
      />;
    case 'inline':
      return <InlineWidget
        updateFormattingOption={props.updateFormattingOption}
        formattingOptions={props.formattingOptions}
      />;
    case 'top_bar':
      return <TopBarWidget
        updateFormattingOption={props.updateFormattingOption}
        formattingOptions={props.formattingOptions}
      />;
    case 'bottom_bar':
      return <BottomBarWidget
        updateFormattingOption={props.updateFormattingOption}
        formattingOptions={props.formattingOptions}
      />;
    case 'fullscreen':
      return <FullscreenWidget
        updateFormattingOption={props.updateFormattingOption}
        formattingOptions={props.formattingOptions}
      />;
    default:
      console.debug('Unrecognized widget type', props.formattingOptions.widgetType);
  }
}

export default PlacementOptions;
