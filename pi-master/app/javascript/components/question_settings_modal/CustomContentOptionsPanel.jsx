import React from 'react';
import PropTypes from 'prop-types';

import NumberFormat from 'react-number-format';
import {SketchPicker} from 'react-color';

import CollapsiblePanel from '../CollapsiblePanel';
import {minValidation, maxValidation} from '../NumberValidations';
import RichTextEditor from './RichTextEditor';

import {updateLocalAndNodeProperties} from './QuestionSettingsPanelHelpers.js';

CustomContentOptionsPanel.propTypes = {
  node: PropTypes.object.isRequired,
  engine: PropTypes.object.isRequired,
};

/**
 * The custom content question options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function CustomContentOptionsPanel(props) {
  const [questionProperties, setQuestionProperties] = React.useState({
    fullscreen: props.node.question.fullscreen || 0,
    autocloseEnabled: props.node.question.autocloseEnabled || 0,
    autocloseDelay: props.node.question.autocloseDelay || 0,
    autoredirectEnabled: props.node.question.autoredirectEnabled || 0,
    autoredirectDelay: props.node.question.autoredirectDelay || 0,
    autoredirectUrl: props.node.question.autoredirectUrl || '',
    showAfterAAO: props.node.question.showAfterAAO || false,
    backgroundColor: props.node.question.backgroundColor || '',
    customContent: props.node.question.customContent || '',
    opacity: props.node.question.opacity || 0,
  });

  const onQuestionPropertyChange = (newObject) => {
    updateLocalAndNodeProperties(setQuestionProperties, questionProperties, props.node, newObject);
  };

  // TODO: Validate RGB
  const FullscreenOptions = () => {
    const [showColorPicker, setShowColorPicker] = React.useState(false);
    const [localColour, setLocalColour] = React.useState(
        questionProperties.backgroundColor || '#000',
    );

    return (
      <div className='options-row'>
        <span>Background color</span>
        <input
          className='number-input background-color'
          defaultValue={questionProperties.backgroundColor}
          onBlur={(e) => {
            onQuestionPropertyChange({backgroundColor: e.target.value});
          }}
        />
        <div
          className='color-picker-preview'
          style={{
            backgroundColor: questionProperties.backgroundColor || '#000',
          }}
          onClick={() => setShowColorPicker(true)}
        />

        {
          showColorPicker ?
            <div className='color-picker-popover'>
              <div
                className='color-picker-cover'
                onClick={() => {
                  onQuestionPropertyChange({backgroundColor: localColour});
                  setShowColorPicker(false);
                }}
              />
              <SketchPicker
                disableAlpha={true}
                color={localColour}
                onChangeComplete={({hex}) => {
                  setLocalColour(hex);
                }}
              />
            </div> :
              null
        }

        <span>Opacity</span>
        <NumberFormat
          className='number-input'
          value={questionProperties.opacity}
          decimalSeparator={null}
          isAllowed={(values) => {
            return minValidation(values, 0) && maxValidation(values, 100);
          }}
          onBlur={(e) => {
            onQuestionPropertyChange({opacity: e.target.value});
          }}
        />
        <span>%</span>
      </div>
    );
  };

  const Options = () => {
    return (
      <>
        <div className='options-row'>
          <input
            type="checkbox"
            onChange={(e) => {
              onQuestionPropertyChange({fullscreen: e.target.checked});
            }}
            value={questionProperties.fullscreen}
            checked={questionProperties.fullscreen}
          />
          <span>Full screen take-over</span>
        </div>
        { questionProperties.fullscreen ? <FullscreenOptions /> : null }
        <div className='options-row'>
          <input
            type="checkbox"
            onChange={(e) => {
              onQuestionPropertyChange({autocloseEnabled: e.target.checked});
            }}
            value={questionProperties.autocloseEnabled}
            checked={questionProperties.autocloseEnabled}
          />
          <span>Auto-close after</span>
          <NumberFormat
            className='number-input'
            value={questionProperties.autocloseDelay}
            thousandSeparator={false}
            decimalSeparator={null}
            allowNegative={false}
            onBlur={(e) => {
              onQuestionPropertyChange({autocloseDelay: e.target.value});
            }}
          />
          <span>seconds</span>
        </div>
        <div className='options-row'>
          <input
            type="checkbox"
            onChange={(e) => {
              onQuestionPropertyChange({showAfterAAO: e.target.checked});
            }}
            value={questionProperties.showAfterAAO}
            checked={questionProperties.showAfterAAO}
          />
          <span>Show after AAO (in place of "Thank You")</span>
        </div>
        <div className='options-row'>
          <input
            type="checkbox"
            onChange={(e) => {
              onQuestionPropertyChange({autoredirectEnabled: e.target.checked});
            }}
            value={questionProperties.autoredirectEnabled}
            checked={questionProperties.autoredirectEnabled}
          />
          <span>Auto-redirect to</span>
          <input
            defaultValue={questionProperties.autoredirectUrl}
            onBlur={(e) => {
              onQuestionPropertyChange({autoredirectUrl: e.target.value});
            }}
          />
          <span>after</span>
          <NumberFormat
            className='number-input'
            value={questionProperties.autoredirectDelay}
            thousandSeparator={false}
            decimalSeparator={null}
            allowNegative={false}
            onBlur={(e) => {
              onQuestionPropertyChange({autoredirectDelay: e.target.value});
            }}
          />
          <span>seconds</span>
        </div>
      </>
    );
  };

  return (
    <>
      <CollapsiblePanel panelTitle='Text'>
        <RichTextEditor
          engine={props.engine}
          node={props.node}
          questionProperties={questionProperties}
          onQuestionPropertyChange={onQuestionPropertyChange}
          questionPropertyName="customContent"
        />
      </CollapsiblePanel>
      <CollapsiblePanel panelTitle='Options'>
        <Options />
      </CollapsiblePanel>
    </>
  );
}

export default CustomContentOptionsPanel;
