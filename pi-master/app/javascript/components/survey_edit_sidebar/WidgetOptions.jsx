import React from 'react';
import PropTypes from 'prop-types';

import CollapsiblePanel from '../CollapsiblePanel';

import DockedWidgetIcon from '../../images/survey_editor/widget_types/docked_widget.png';
import InlineWidgetIcon from '../../images/survey_editor/widget_types/inline.png';
import TopBarWidgetIcon from '../../images/survey_editor/widget_types/top_bar.png';
import BottomBarWidgetIcon from '../../images/survey_editor/widget_types/bottom_bar.png';
import FullscreenWidgetIcon from '../../images/survey_editor/widget_types/fullscreen.png';

import PlacementOptions from './widget_options/PlacementOptions';

WidgetTypeOptions.propTypes = {
  updateFormattingOption: PropTypes.func.isRequired,
  formattingOptions: PropTypes.object.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};
/**
 * The survey widget type options
 *
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function WidgetTypeOptions(props) {
  const widgets = [
    {value: 'docked_widget', icon: DockedWidgetIcon, label: 'Docked'},
    {value: 'inline', icon: InlineWidgetIcon, label: 'Inline'},
    {value: 'top_bar', icon: TopBarWidgetIcon, label: 'Top Bar'},
    {value: 'bottom_bar', icon: BottomBarWidgetIcon, label: 'Bottom Bar'},
    {value: 'fullscreen', icon: FullscreenWidgetIcon, label: 'Overlay'},
  ];

  return (
    <CollapsiblePanel
      panelTitle='Widget Type'
      panelExpansionSettings={props.panelExpansionSettings}
      updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      expandByDefault
    >
      <div className='sidebar-option-row'>
        <ul className='sidebar-widgets-list'>
          {
            widgets.map((widget) => {
              return (
                <li key={widget.value}>
                  <label htmlFor={widget.value}>
                    <img src={widget.icon} />
                    {widget.label}
                  </label>

                  <input
                    type="radio"
                    id={widget.value}
                    value={widget.value}
                    onChange={(e) => {
                      props.updateFormattingOption({surveyType: e.target.value});
                    }}
                    checked={props.formattingOptions.surveyType === widget.value}
                    name={'survey_type'}
                  />
                </li>
              );
            })
          }
        </ul>
      </div>

      <PlacementOptions
        updateFormattingOption={props.updateFormattingOption}
        formattingOptions={props.formattingOptions}
      />
    </CollapsiblePanel>
  );
}

export default WidgetTypeOptions;
