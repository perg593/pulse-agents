import React from 'react';
import PropTypes from 'prop-types';

import {CustomPicker} from 'react-color';
import {
  Alpha, EditableInput, Hue, Saturation,
} from 'react-color/lib/components/common';

// A custom colour picker provided to react-color's CustomPicker. react-color
// provides the individual components which we assemble and provide change
// callbacks to. CustomPicker forwards ColorPicker props.
// See http://casesandberg.github.io/react-color/#create for more details.
export const ColorPicker = ({rgb, hex, hsl, hsv, onChange}) => {
  // "Borrowed" from react-color's SketchFields field input parser
  // https://github.com/casesandberg/react-color/blob/bc9a0e1dc5d11b06c511a8e02a95bd85c7129f4b/src/components/sketch/SketchFields.js
  const handleTextInputChange = (data, e) => {
    if (data.hex) {
      color.isValidHex(data.hex) && onChange({
        hex: data.hex,
        source: 'hex',
      }, e);
    } else if (data.r || data.g || data.b) {
      onChange({
        r: data.r || rgb.r,
        g: data.g || rgb.g,
        b: data.b || rgb.b,
        a: rgb.a,
        source: 'rgb',
      }, e);
    } else if (data.a) {
      if (data.a < 0) {
        data.a = 0;
      } else if (data.a > 100) {
        data.a = 100;
      }

      data.a /= 100;
      onChange({
        h: hsl.h,
        s: hsl.s,
        l: hsl.l,
        a: data.a,
        source: 'rgb',
      }, e);
    }
  };

  return (
    <div className='color-picker'>
      <div className='saturation-picker-wrapper'>
        <Saturation hsl={hsl} hsv={hsv} onChange={onChange} />
      </div>

      <div className='hue-picker-wrapper'>
        <Hue hsl={hsl} onChange={onChange} />
      </div>

      <div className='alpha-picker-wrapper'>
        <Alpha
          rgb={rgb}
          hsl={hsl}
          onChange={onChange}
        />
      </div>

      <div className='rgb-fields-wrapper'>
        <EditableInput
          label='HEX'
          value={hex}
          onChangeComplete={handleTextInputChange}
        />
        <EditableInput
          label='R'
          value={rgb.r}
          onChange={handleTextInputChange}
        />
        <EditableInput
          label='G'
          value={rgb.g}
          onChange={handleTextInputChange}
        />
        <EditableInput
          label='B'
          value={rgb.b}
          onChange={handleTextInputChange}
        />
        <EditableInput
          label='Alpha'
          value={rgb.a}
          onChange={handleTextInputChange}
        />
      </div>
    </div>
  );
};

ColorPicker.propTypes = {
  rgb: PropTypes.object,
  hex: PropTypes.string,
  hsl: PropTypes.object,
  hsv: PropTypes.object,
  onChange: PropTypes.func,
};

export default CustomPicker(ColorPicker);
