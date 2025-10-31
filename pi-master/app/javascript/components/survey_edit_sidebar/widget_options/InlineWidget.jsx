import React from 'react';
import PropTypes from 'prop-types';

import SDKHeightOption from './SDKHeightOption';

import WidgetListItem from '../WidgetListItem';

import AboveIcon from '../../../images/survey_editor/widget_positions/inline_above.png';
import BelowIcon from '../../../images/survey_editor/widget_positions/inline_below.png';
import InsideFirstIcon from '../../../images/survey_editor/widget_positions/inline_inside_first.png';
import InsideLastIcon from '../../../images/survey_editor/widget_positions/inline_inside_last.png';
import InsideIcon from '../../../images/survey_editor/widget_positions/inline_inside.png';

InlineWidget.propTypes = {
  updateFormattingOption: PropTypes.func.isRequired,
  formattingOptions: PropTypes.object.isRequired,
};

/**
 * Options specific to inline widgets
 *
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function InlineWidget(props) {
  const siblingModeActive = ['above', 'below'].
      includes(props.formattingOptions.inlineTargetPosition);

  const [showSubwidgets, setSubwidgets] = React.useState(siblingModeActive);

  const updateInlineTargetPosition = (e) => {
    props.updateFormattingOption({inlineTargetPosition: e.target.value});
  };

  const widgets = [
    {
      value: 'before',
      icon: AboveIcon,
      label: 'Above',
      onChange: updateInlineTargetPosition,
      name: 'inline_target_position',
    },
    {
      value: 'inside',
      icon: InsideIcon,
      label: 'Inside',
      checked: () => siblingModeActive,
      name: 'inside_panel_opener',
      onChange: () => {
        if (!showSubwidgets) {
          props.updateFormattingOption({inlineTargetPosition: 'above'});
        }

        setSubwidgets(!showSubwidgets);
      },
    },
    {
      value: 'after',
      icon: BelowIcon,
      label: 'Below',
      onChange: updateInlineTargetPosition,
      name: 'inline_target_position',
    },
  ];

  const subWidgets = [
    {
      value: 'above',
      icon: InsideFirstIcon,
      label: 'First',
      onChange: updateInlineTargetPosition,
      name: 'inline_target_position',
    },
    {
      value: 'below',
      icon: InsideLastIcon,
      label: 'Last',
      onChange: updateInlineTargetPosition,
      name: 'inline_target_position',
    },
  ];

  return (
    <>
      <div className='sidebar-option-row'>
        <label
          className='sidebar-label'
          htmlFor='inline_target_selector_text_field'
        >
          Target:
        </label>
        <textarea
          id='inline_target_selector_text_field'
          className='tall'
          defaultValue={props.formattingOptions.inlineTargetSelector}
          onBlur={(e) => props.updateFormattingOption({
            inlineTargetSelector: e.target.value,
          })}
          placeholder='Enter CSS selector for target element. Elements in shadow DOMs can be targeted by adding ::shadow to the shadow DOM parent'
        />
      </div>
      <div className='sidebar-option-row'>
        <label
          className='sidebar-label'
          htmlFor='mobile_inline_target_selector_text_field'
        >
          Mobile Target:
        </label>
        <textarea
          id='mobile_inline_target_selector_text_field'
          defaultValue={props.formattingOptions.mobileInlineTargetSelector}
          onBlur={(e) => props.updateFormattingOption({
            mobileInlineTargetSelector: e.target.value,
          })}
          placeholder='Enter CSS selector for target element'
        />
      </div>
      <div className='sidebar-option-row'>
        <label
          className='sidebar-label'
          htmlFor='sdk_inline_target_selector_text_field'
        >
          SDK Target:
        </label>
        <textarea
          id='sdk_inline_target_selector_text_field'
          defaultValue={props.formattingOptions.sdkInlineTargetSelector}
          onBlur={(e) => props.updateFormattingOption({
            sdkInlineTargetSelector: e.target.value,
          })}
          placeholder='Enter the name of the identifier'
        />
      </div>
      <div className='sidebar-option-row'>
        <h4>Location:</h4>
        <ul className='sidebar-widgets-list short-list'>
          {
            widgets.map((widget) => {
              return <WidgetListItem
                key={widget.value}
                widget={widget}
                value={props.formattingOptions.inlineTargetPosition}
              />;
            })
          }
        </ul>
      </div>
      {
        showSubwidgets ?
          <div className='sidebar-option-row'>
            <h4>Order within Target:</h4>
            <ul className='sidebar-widgets-list short-list'>
              {
                subWidgets.map((widget) => {
                  return <WidgetListItem
                    key={widget.value}
                    widget={widget}
                    value={props.formattingOptions.inlineTargetPosition}
                  />;
                })
              }
            </ul>
          </div> : null
      }
      <SDKHeightOption
        options={props.formattingOptions}
        updateFunction={props.updateFormattingOption}
      />
    </>
  );
}

export default InlineWidget;
