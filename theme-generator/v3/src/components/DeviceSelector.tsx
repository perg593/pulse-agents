/**
 * Phase 4.0: Device Selector (Desktop / iPhone / Android)
 */

import type { DeviceType } from '../types/theme';

interface DeviceSelectorProps {
  device: DeviceType;
  onChange: (device: DeviceType) => void;
}

export function DeviceSelector({ device, onChange }: DeviceSelectorProps) {
  return (
    <div className="device-selector">
      <span className="selector-label">Devices:</span>
      <div className="selector-buttons">
        <button
          type="button"
          className={`selector-button ${device === 'desktop' ? 'active' : ''}`}
          onClick={() => onChange('desktop')}
        >
          Desktop
        </button>
        <button
          type="button"
          className={`selector-button ${device === 'iphone' ? 'active' : ''}`}
          onClick={() => onChange('iphone')}
        >
          iPhone
        </button>
        <button
          type="button"
          className={`selector-button ${device === 'android' ? 'active' : ''}`}
          onClick={() => onChange('android')}
        >
          Android
        </button>
      </div>
    </div>
  );
}

