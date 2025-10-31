import React from 'react';
import PropTypes from 'prop-types';

import ColorPicker from './ColorPicker';

import OutsideClickHandler from 'react-outside-click-handler';

const ColorPickerPopup = (props) => {
  const [
    selectedLegendId,
    setSelectedLegendId,
  ] = React.useState(props.legend[0].id);

  const [previewColor, setPreviewColor] = React.useState(props.legend[0].color);

  /**
   * Returns The currently selected legend item
   * @return {object} - A legend item
   * {
   *    id: possibleAnswer.id,
   *    name: possibleAnswer.content,
   *    color: possibleAnswer's colour
   *    colorUpdateUrl: URL to send colour updates to
   * }
   */
  function selectedItem() {
    return props.legend.find((item) => item.id === selectedLegendId);
  };

  return (
    <OutsideClickHandler onOutsideClick={props.hideColorPicker}>
      <div className='color-picker-popover'>
        <div className='color-picker-body'>
          <div className='color-picker-output-container'>
            <ul className='color-legend'>
              {
                props.legend.map((item) => {
                  return (
                    <li
                      key={item.id}
                      onClick={() => setSelectedLegendId(item.id)}
                      className={`color-legend-item ${selectedLegendId === item.id ? 'selected' : ''}`}
                    >
                      <span
                        className='color-icon'
                        style={{backgroundColor: item.color}}
                      ></span>
                      <span>{item.name}</span>
                    </li>
                  );
                })
              }
            </ul>

            <div className='color-preview-wrapper'>
              <div className='color-preview-container'>
                <span>From:</span>
                <span
                  className='color-preview-swatch'
                  style={{
                    backgroundColor: selectedItem().color
                  }}
                ></span>
              </div>
              <div className='color-preview-container'>
                <span>To:</span>
                <span
                  className='color-preview-swatch'
                  style={{backgroundColor: previewColor}}
                ></span>
              </div>
            </div>
          </div>

          <ColorPicker
            color={previewColor}
            onChangeComplete={({hex}) => {
              setPreviewColor(hex);
            }}
          />
        </div>
        <div className='color-picker-footer'>
          <button
            onClick={() => {
              props.updateColor(selectedLegendId, previewColor, selectedItem().colorUpdateUrl);
            }}
          >
            SAVE
          </button>
          <button onClick={props.hideColorPicker}>
            CANCEL
          </button>
        </div>
      </div>
    </OutsideClickHandler>
  );
};

ColorPickerPopup.propTypes = {
  hideColorPicker: PropTypes.func.isRequired,
  updateColor: PropTypes.func.isRequired,
  legend: PropTypes.array.isRequired,
};

export default ColorPickerPopup;
