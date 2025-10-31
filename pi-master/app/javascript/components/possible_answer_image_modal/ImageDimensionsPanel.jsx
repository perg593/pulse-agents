import React from 'react';
import PropTypes from 'prop-types';

import DesktopIcon from '../../images/survey_editor/monitor.svg';
import TabletIcon from '../../images/survey_editor/tablet.svg';
import MobileIcon from '../../images/survey_editor/mobile_alt.svg';

import CollapsiblePanel from '../CollapsiblePanel';

ImageDimensionsPanel.propTypes = {
  node: PropTypes.object,
  possibleAnswer: PropTypes.object.isRequired,
};

/**
 * Image dimensions options panel
 * @param { Object } props
 * @return { JSX.Element } the panel
*/
function ImageDimensionsPanel(props) {
  const [nodeProperties, setNodeProperties] = React.useState({
    imageHeight: props.possibleAnswer.imageHeight || '',
    imageHeightMobile: props.possibleAnswer.imageHeightMobile || '',
    imageHeightTablet: props.possibleAnswer.imageHeightTablet || '',
    imageWidth: props.possibleAnswer.imageWidth || '',
    imageWidthMobile: props.possibleAnswer.imageWidthMobile || '',
    imageWidthTablet: props.possibleAnswer.imageWidthTablet || '',
    imageAlt: props.possibleAnswer.imageAlt || '',
  });

  const onNodePropertyChange = (newObject) => {
    setNodeProperties(
        {
          ...nodeProperties,
          ...newObject,
        },
    );

    props.node.updatePossibleAnswer(props.possibleAnswer, newObject);
  };

  const DeviceHeader = ({icon, label}) => {
    return (
      <div className='image-dimension-image-container'>
        <span
          className='device-icon'
          style={{
            maskImage: `url(${icon})`,
            WebkitMaskImage: `url(${icon})`,
          }}
        >
        </span>
        <span>
          {label}
        </span>
      </div>
    );
  };
  DeviceHeader.propTypes = {
    icon: PropTypes.string.isRequired,
    label: PropTypes.string.isRequired,
  };

  const ImageDimensionOptions = () => {
    return (
      <div className='image-dimension-options-container'>
        <div className='image-dimension-label-wrapper'>
          <label htmlFor='first_image_width_field'>
            Width
          </label>
          <label htmlFor='first_image_height_field'>
            Height
          </label>
          <label htmlFor='alt_text_field'>
            Alt. Text
          </label>
        </div>

        <div className='image-dimension-fields-wrapper'>
          <div className='device-wrapper'>
            <DeviceHeader icon={DesktopIcon} label='desktop' />
            <DeviceHeader icon={TabletIcon} label='tablet' />
            <DeviceHeader icon={MobileIcon} label='mobile' />
          </div>
          <div className='image-dimension-fields-container'>
            <input
              id='first_image_width_field'
              value={nodeProperties.imageWidth}
              onChange={(e) => {
                onNodePropertyChange({imageWidth: e.target.value});
              }}
            />
            <input
              value={nodeProperties.imageWidthTablet}
              onChange={(e) => {
                onNodePropertyChange({imageWidthTablet: e.target.value});
              }}
            />
            <input
              value={nodeProperties.imageWidthMobile}
              onChange={(e) => {
                onNodePropertyChange({imageWidthMobile: e.target.value});
              }}
            />
          </div>
          <div className='image-dimension-fields-container'>
            <input
              id='first_image_height_field'
              value={nodeProperties.imageHeight}
              onChange={(e) => {
                onNodePropertyChange({imageHeight: e.target.value});
              }}
            />
            <input
              value={nodeProperties.imageHeightTablet}
              onChange={(e) => {
                onNodePropertyChange({imageHeightTablet: e.target.value});
              }}
            />
            <input
              value={nodeProperties.imageHeightMobile}
              onChange={(e) => {
                onNodePropertyChange({imageHeightMobile: e.target.value});
              }}
            />
          </div>
          <div className='image-dimension-fields-container'>
            <input
              id='alt_text_field'
              className='alt-text-input'
              value={nodeProperties.imageAlt}
              onChange={(e) => onNodePropertyChange({imageAlt: e.target.value})}
            />
          </div>
        </div>
      </div>
    );
  };

  return (
    <CollapsiblePanel panelTitle='Image Configuration'>
      <ImageDimensionOptions
        node={props.node}
        possibleAnswer={props.possibleAnswer}
      />
    </CollapsiblePanel>
  );
}

export default ImageDimensionsPanel;
