import { useState, useEffect, useRef } from 'react';

interface ColorInputProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  extractedColors?: string[];
  paletteColors?: string[]; // Phase 3.95: Full palette colors from ThemeTokensLite
  showPresetsAlways?: boolean; // Phase 3.95: Always show presets in Palette section
  useDropdown?: boolean; // Phase 3.95: Use dropdown instead of toggle in other sections
  tokenPath?: string; // Phase 4.6: Token path for reset functionality
  onReset?: () => void; // Phase 4.6: Reset callback
}

export function ColorInput({ 
  label, 
  value, 
  onChange, 
  extractedColors = [],
  paletteColors = [],
  showPresetsAlways = false,
  useDropdown = false,
  onReset
}: ColorInputProps) {
  const [showPresets, setShowPresets] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);

  // Combine extracted colors and palette colors
  const allPresets = [...new Set([...paletteColors, ...extractedColors])].filter(Boolean);
  const hasPresets = allPresets.length > 0;

  // Phase 4.6: Reset button component
  const ResetButton = onReset ? (
    <button
      type="button"
      className="reset-token-button"
      onClick={(e) => {
        e.stopPropagation();
        onReset();
      }}
      title={`Reset ${label} to baseline`}
    >
      ↺
    </button>
  ) : null;

  // For Palette section: always show presets
  if (showPresetsAlways && hasPresets) {
    return (
      <div className="color-input-group">
        <div className="color-input-label-row">
          <label className="color-input-label">{label}</label>
          {ResetButton}
        </div>
        <div className="color-input-controls">
          <div className="preset-colors-always-visible">
            {allPresets.map((color, index) => (
              <button
                key={index}
                type="button"
                className={`preset-color-chip ${value.toLowerCase() === color.toLowerCase() ? 'active' : ''}`}
                style={{ backgroundColor: color }}
                onClick={() => onChange(color)}
                title={color}
              />
            ))}
          </div>
          <div className="color-input-row">
            <input
              type="color"
              value={value}
              onChange={(e) => onChange(e.target.value)}
              className="color-picker"
            />
            <input
              type="text"
              value={value}
              onChange={(e) => onChange(e.target.value)}
              className="color-text-input"
              placeholder="#000000"
            />
          </div>
        </div>
      </div>
    );
  }

  // For other sections: use dropdown if requested
  if (useDropdown && hasPresets) {
    const dropdownRef = useRef<HTMLDivElement>(null);
    
    // Close dropdown when clicking outside (Phase 3.95)
    useEffect(() => {
      function handleClickOutside(event: MouseEvent) {
        if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
          setShowDropdown(false);
        }
      }
      
      if (showDropdown) {
        document.addEventListener('mousedown', handleClickOutside);
        return () => {
          document.removeEventListener('mousedown', handleClickOutside);
        };
      }
    }, [showDropdown]);
    
    return (
      <div className="color-input-group">
        <div className="color-input-label-row">
          <label className="color-input-label">{label}</label>
          {ResetButton}
        </div>
        <div className="color-input-controls">
          <div className="color-preset-dropdown" ref={dropdownRef}>
            <button
              type="button"
              className="btn-preset-dropdown"
              onClick={() => setShowDropdown(!showDropdown)}
            >
              Use palette color...
            </button>
            {showDropdown && (
              <div className="preset-dropdown-menu">
                {allPresets.map((color, index) => (
                  <button
                    key={index}
                    type="button"
                    className="preset-dropdown-item"
                    onClick={() => {
                      onChange(color);
                      setShowDropdown(false);
                    }}
                    title={color}
                  >
                    <span className="preset-color-preview" style={{ backgroundColor: color }}></span>
                    <span className="preset-color-value">{color}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
          <div className="color-input-row">
            <input
              type="color"
              value={value}
              onChange={(e) => onChange(e.target.value)}
              className="color-picker"
            />
            <input
              type="text"
              value={value}
              onChange={(e) => onChange(e.target.value)}
              className="color-text-input"
              placeholder="#000000"
            />
          </div>
        </div>
      </div>
    );
  }

  // Fallback: original toggle behavior (for backward compatibility)
  return (
    <div className="color-input-group">
      <div className="color-input-label-row">
        <label className="color-input-label">{label}</label>
        {ResetButton}
      </div>
      <div className="color-input-controls">
        {hasPresets && (
          <div className="color-presets">
            <button
              type="button"
              className="btn-preset-toggle"
              onClick={() => setShowPresets(!showPresets)}
            >
              {showPresets ? 'Hide Presets' : 'Show Presets'}
            </button>
            {showPresets && (
              <div className="preset-colors">
                {allPresets.map((color, index) => (
                  <button
                    key={index}
                    type="button"
                    className="preset-color-chip"
                    style={{ backgroundColor: color }}
                    onClick={() => onChange(color)}
                    title={color}
                  />
                ))}
              </div>
            )}
          </div>
        )}
        <div className="color-input-row">
          <input
            type="color"
            value={value}
            onChange={(e) => onChange(e.target.value)}
            className="color-picker"
          />
          <input
            type="text"
            value={value}
            onChange={(e) => onChange(e.target.value)}
            className="color-text-input"
            placeholder="#000000"
          />
        </div>
      </div>
    </div>
  );
}
