import React from 'react';
import PropTypes from 'prop-types';
import DebouncedInput from '../../../../components/DebouncedInput';

ViewportConfig.propTypes = {
  viewportConfig: PropTypes.object,
  onViewportConfigChange: PropTypes.func.isRequired,
};

/**
 * Component for configuring viewport dimensions for screenshots.
 * @param {Object} props - see propTypes
 * @return {JSX.Element}
 */
function ViewportConfig(props) {
  const {viewportConfig = {}, onViewportConfigChange} = props;

  /**
   * Update a viewport configuration value.
   * @param {string} key - The viewport config key to update
   * @param {string} value - The new value (will be converted to number if valid)
   */
  const updateViewportConfig = (key, value) => {
    // Convert to number if it's a valid numeric string, otherwise keep as string
    const numericValue = value && value.match(/^\d+$/) ? parseInt(value, 10) : value;

    onViewportConfigChange({
      ...viewportConfig,
      [key]: numericValue,
    });
  };

  return (
    <div className="form-group">
      <label>Screenshot Resolution (Optional)</label>
      <p className="hint">
        Configure custom viewport dimensions for screenshots. Leave blank to use defaults.
        <br />
        Valid ranges: Width 320-3840px, Height 240-2160px
      </p>
      <div className="controls">
        <div className="viewport-config-section">
          <h4>Desktop</h4>
          <div className="viewport-input-row">
            <div className="viewport-input-group">
              <label htmlFor="desktop_width">Width (px)</label>
              <DebouncedInput
                id="desktop_width"
                value={viewportConfig.desktop_width || ''}
                onChange={(value) => updateViewportConfig('desktop_width', value)}
                placeholder="1920"
                className="form-control"
              />
            </div>
            <div className="viewport-input-group">
              <label htmlFor="desktop_height">Height (px)</label>
              <DebouncedInput
                id="desktop_height"
                value={viewportConfig.desktop_height || ''}
                onChange={(value) => updateViewportConfig('desktop_height', value)}
                placeholder="1080"
                className="form-control"
              />
            </div>
          </div>
        </div>

        <div className="viewport-config-section">
          <h4>Mobile</h4>
          <div className="viewport-input-row">
            <div className="viewport-input-group">
              <label htmlFor="mobile_width">Width (px)</label>
              <DebouncedInput
                id="mobile_width"
                value={viewportConfig.mobile_width || ''}
                onChange={(value) => updateViewportConfig('mobile_width', value)}
                placeholder="375"
                className="form-control"
              />
            </div>
            <div className="viewport-input-group">
              <label htmlFor="mobile_height">Height (px)</label>
              <DebouncedInput
                id="mobile_height"
                value={viewportConfig.mobile_height || ''}
                onChange={(value) => updateViewportConfig('mobile_height', value)}
                placeholder="667"
                className="form-control"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default ViewportConfig;
