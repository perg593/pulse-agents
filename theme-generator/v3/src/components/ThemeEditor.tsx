import { useState } from 'react';
import { useThemeStore } from '../stores/themeStore';
import { CollapsibleSection } from './CollapsibleSection';
import { ColorInput } from './ColorInput';
import { updateToken, getToken, resetTokenToBaseline, resetTokenGroup, resetThemeToBaseline, getTokensByGroup } from '../theme/tokenManager';

export function ThemeEditor() {
  const activeTheme = useThemeStore((state) => state.getActiveTheme());
  const activeProject = useThemeStore((state) => state.getActiveProject());
  const [showResetConfirm, setShowResetConfirm] = useState(false);

  if (!activeTheme || !activeProject) {
    return (
      <div className="theme-editor">
        <p className="editor-empty">No theme selected</p>
      </div>
    );
  }

  const extractedColors = activeProject.extractedColors || [];
  
  // Phase 3.95: Build full palette colors array from ThemeTokensLite
  const paletteColors = [
    activeTheme.palette.background,
    activeTheme.palette.surface,
    activeTheme.palette.surfaceAlt,
    activeTheme.palette.textPrimary,
    activeTheme.palette.textSecondary,
    activeTheme.palette.brandPrimary,
    activeTheme.palette.brandSecondary,
    activeTheme.palette.accent,
    activeTheme.palette.danger,
    activeTheme.palette.success
  ].filter(Boolean);

  const handleResetTheme = () => {
    if (showResetConfirm) {
      resetThemeToBaseline();
      setShowResetConfirm(false);
    } else {
      setShowResetConfirm(true);
      setTimeout(() => setShowResetConfirm(false), 3000);
    }
  };

  const handleResetGroup = (group: 'palette' | 'typography' | 'component' | 'layout') => {
    const tokens = getTokensByGroup(group);
    const tokenPaths = tokens.map(t => t.path);
    resetTokenGroup(tokenPaths);
  };

  return (
    <div className="theme-editor">
      <div className="theme-editor-header">
        <div>
          <h2>Theme Editor</h2>
          <div className="theme-name-display">{activeTheme.name}</div>
        </div>
        <button
          type="button"
          className={`reset-theme-button ${showResetConfirm ? 'confirm' : ''}`}
          onClick={handleResetTheme}
          title={showResetConfirm ? 'Click again to confirm' : 'Reset theme to baseline'}
        >
          {showResetConfirm ? 'Confirm Reset' : 'Reset Theme'}
        </button>
      </div>
      
      {/* Palette Section */}
      <CollapsibleSection 
        title="Palette" 
        defaultOpen={true}
        actions={
          <button
            type="button"
            className="reset-group-button"
            onClick={() => handleResetGroup('palette')}
            title="Reset all palette tokens to baseline"
          >
            Reset Group
          </button>
        }
      >
        <div className="editor-fields">
          <ColorInput
            label="Background"
            value={getToken<string>('palette.background') || activeTheme.palette.background}
            onChange={(value) => updateToken('palette.background', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            showPresetsAlways={true}
            tokenPath="palette.background"
            onReset={() => resetTokenToBaseline('palette.background')}
          />
          <ColorInput
            label="Surface"
            value={getToken<string>('palette.surface') || activeTheme.palette.surface}
            onChange={(value) => updateToken('palette.surface', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            showPresetsAlways={true}
            tokenPath="palette.surface"
            onReset={() => resetTokenToBaseline('palette.surface')}
          />
          <ColorInput
            label="Text Primary"
            value={getToken<string>('palette.textPrimary') || activeTheme.palette.textPrimary}
            onChange={(value) => updateToken('palette.textPrimary', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            showPresetsAlways={true}
            tokenPath="palette.textPrimary"
            onReset={() => resetTokenToBaseline('palette.textPrimary')}
          />
          <ColorInput
            label="Text Secondary"
            value={getToken<string>('palette.textSecondary') || activeTheme.palette.textSecondary}
            onChange={(value) => updateToken('palette.textSecondary', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            showPresetsAlways={true}
            tokenPath="palette.textSecondary"
            onReset={() => resetTokenToBaseline('palette.textSecondary')}
          />
          <ColorInput
            label="Brand Primary"
            value={getToken<string>('palette.brandPrimary') || activeTheme.palette.brandPrimary}
            onChange={(value) => updateToken('palette.brandPrimary', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            showPresetsAlways={true}
            tokenPath="palette.brandPrimary"
            onReset={() => resetTokenToBaseline('palette.brandPrimary')}
          />
          <ColorInput
            label="Brand Secondary"
            value={getToken<string>('palette.brandSecondary') || activeTheme.palette.brandSecondary}
            onChange={(value) => updateToken('palette.brandSecondary', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            showPresetsAlways={true}
            tokenPath="palette.brandSecondary"
            onReset={() => resetTokenToBaseline('palette.brandSecondary')}
          />
          <ColorInput
            label="Accent"
            value={getToken<string>('palette.accent') || activeTheme.palette.accent}
            onChange={(value) => updateToken('palette.accent', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            showPresetsAlways={true}
            tokenPath="palette.accent"
            onReset={() => resetTokenToBaseline('palette.accent')}
          />
          <ColorInput
            label="Success"
            value={getToken<string>('palette.success') || activeTheme.palette.success}
            onChange={(value) => updateToken('palette.success', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            showPresetsAlways={true}
            tokenPath="palette.success"
            onReset={() => resetTokenToBaseline('palette.success')}
          />
          <ColorInput
            label="Danger"
            value={getToken<string>('palette.danger') || activeTheme.palette.danger}
            onChange={(value) => updateToken('palette.danger', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            showPresetsAlways={true}
            tokenPath="palette.danger"
            onReset={() => resetTokenToBaseline('palette.danger')}
          />
        </div>
      </CollapsibleSection>

      {/* Typography Section */}
      <CollapsibleSection 
        title="Typography" 
        defaultOpen={false}
        actions={
          <button
            type="button"
            className="reset-group-button"
            onClick={() => handleResetGroup('typography')}
            title="Reset all typography tokens to baseline"
          >
            Reset Group
          </button>
        }
      >
        <div className="editor-fields">
          {/* Phase 4.7: Enhanced Typography Roles */}
          <h4 style={{ fontSize: 13, fontWeight: 600, marginBottom: 12, marginTop: 8, color: '#374151' }}>Heading</h4>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Font Family</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.heading.fontFamily')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="text"
              value={getToken<string>('typography.heading.fontFamily') || activeTheme.typography.heading?.fontFamily || activeTheme.typography.fontFamilyHeading || activeTheme.typography.fontFamilyBase}
              onChange={(e) => updateToken('typography.heading.fontFamily', e.target.value, { source: 'themeEditor' })}
              placeholder="system-ui, sans-serif"
            />
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Font Size (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.heading.fontSize')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('typography.heading.fontSize') ?? activeTheme.typography.heading?.fontSize ?? activeTheme.typography.headingSize}
              onChange={(e) => updateToken('typography.heading.fontSize', parseInt(e.target.value) || 18, { source: 'themeEditor' })}
            />
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Font Weight</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.heading.fontWeight')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <select
              value={getToken<number>('typography.heading.fontWeight') ?? activeTheme.typography.heading?.fontWeight ?? 600}
              onChange={(e) => updateToken('typography.heading.fontWeight', parseInt(e.target.value), { source: 'themeEditor' })}
            >
              <option value={400}>400 (Normal)</option>
              <option value={500}>500 (Medium)</option>
              <option value={600}>600 (Semibold)</option>
              <option value={700}>700 (Bold)</option>
            </select>
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Line Height</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.heading.lineHeight')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              step="0.1"
              value={getToken<number>('typography.heading.lineHeight') ?? activeTheme.typography.heading?.lineHeight ?? 1.3}
              onChange={(e) => updateToken('typography.heading.lineHeight', parseFloat(e.target.value) || 1.3, { source: 'themeEditor' })}
            />
          </div>

          <h4 style={{ fontSize: 13, fontWeight: 600, marginBottom: 12, marginTop: 16, color: '#374151' }}>Body</h4>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Font Family</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.body.fontFamily')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="text"
              value={getToken<string>('typography.body.fontFamily') || activeTheme.typography.body?.fontFamily || activeTheme.typography.fontFamilyBase}
              onChange={(e) => updateToken('typography.body.fontFamily', e.target.value, { source: 'themeEditor' })}
              placeholder="system-ui, sans-serif"
            />
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Font Size (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.body.fontSize')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('typography.body.fontSize') ?? activeTheme.typography.body?.fontSize ?? activeTheme.typography.bodySize}
              onChange={(e) => updateToken('typography.body.fontSize', parseInt(e.target.value) || 14, { source: 'themeEditor' })}
            />
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Font Weight</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.body.fontWeight')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <select
              value={getToken<number>('typography.body.fontWeight') ?? activeTheme.typography.body?.fontWeight ?? 400}
              onChange={(e) => updateToken('typography.body.fontWeight', parseInt(e.target.value), { source: 'themeEditor' })}
            >
              <option value={400}>400 (Normal)</option>
              <option value={500}>500 (Medium)</option>
              <option value={600}>600 (Semibold)</option>
              <option value={700}>700 (Bold)</option>
            </select>
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Line Height</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.body.lineHeight')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              step="0.1"
              value={getToken<number>('typography.body.lineHeight') ?? activeTheme.typography.body?.lineHeight ?? 1.5}
              onChange={(e) => updateToken('typography.body.lineHeight', parseFloat(e.target.value) || 1.5, { source: 'themeEditor' })}
            />
          </div>

          <h4 style={{ fontSize: 13, fontWeight: 600, marginBottom: 12, marginTop: 16, color: '#374151' }}>Button</h4>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Font Family</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.button.fontFamily')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="text"
              value={getToken<string>('typography.button.fontFamily') || activeTheme.typography.button?.fontFamily || activeTheme.typography.fontFamilyBase}
              onChange={(e) => updateToken('typography.button.fontFamily', e.target.value, { source: 'themeEditor' })}
              placeholder="system-ui, sans-serif"
            />
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Font Size (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.button.fontSize')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('typography.button.fontSize') ?? activeTheme.typography.button?.fontSize ?? activeTheme.typography.buttonSize}
              onChange={(e) => updateToken('typography.button.fontSize', parseInt(e.target.value) || 14, { source: 'themeEditor' })}
            />
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Font Weight</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.button.fontWeight')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <select
              value={getToken<number>('typography.button.fontWeight') ?? activeTheme.typography.button?.fontWeight ?? 600}
              onChange={(e) => updateToken('typography.button.fontWeight', parseInt(e.target.value), { source: 'themeEditor' })}
            >
              <option value={400}>400 (Normal)</option>
              <option value={500}>500 (Medium)</option>
              <option value={600}>600 (Semibold)</option>
              <option value={700}>700 (Bold)</option>
            </select>
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Letter Spacing (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.button.letterSpacing')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              step="0.1"
              value={getToken<number>('typography.button.letterSpacing') ?? activeTheme.typography.button?.letterSpacing ?? 0.5}
              onChange={(e) => updateToken('typography.button.letterSpacing', parseFloat(e.target.value) || 0.5, { source: 'themeEditor' })}
            />
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Line Height</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('typography.button.lineHeight')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              step="0.1"
              value={getToken<number>('typography.button.lineHeight') ?? activeTheme.typography.button?.lineHeight ?? 1.4}
              onChange={(e) => updateToken('typography.button.lineHeight', parseFloat(e.target.value) || 1.4, { source: 'themeEditor' })}
            />
          </div>
        </div>
      </CollapsibleSection>

      {/* Widget Section */}
      <CollapsibleSection 
        title="Widget" 
        defaultOpen={false}
        actions={
          <button
            type="button"
            className="reset-group-button"
            onClick={() => handleResetGroup('component')}
            title="Reset all widget component tokens to baseline"
          >
            Reset Group
          </button>
        }
      >
        <div className="editor-fields">
          <ColorInput
            label="Header Background"
            value={getToken<string>('components.widget.headerBg') || activeTheme.components.widget.headerBg}
            onChange={(value) => updateToken('components.widget.headerBg', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.widget.headerBg"
            onReset={() => resetTokenToBaseline('components.widget.headerBg')}
          />
          <ColorInput
            label="Header Text"
            value={getToken<string>('components.widget.headerText') || activeTheme.components.widget.headerText}
            onChange={(value) => updateToken('components.widget.headerText', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.widget.headerText"
            onReset={() => resetTokenToBaseline('components.widget.headerText')}
          />
          <ColorInput
            label="Body Background"
            value={getToken<string>('components.widget.bodyBg') || activeTheme.components.widget.bodyBg}
            onChange={(value) => updateToken('components.widget.bodyBg', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.widget.bodyBg"
            onReset={() => resetTokenToBaseline('components.widget.bodyBg')}
          />
          <ColorInput
            label="Body Text"
            value={getToken<string>('components.widget.bodyText') || activeTheme.components.widget.bodyText}
            onChange={(value) => updateToken('components.widget.bodyText', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.widget.bodyText"
            onReset={() => resetTokenToBaseline('components.widget.bodyText')}
          />
          <ColorInput
            label="Border Color"
            value={getToken<string>('components.widget.borderColor') || activeTheme.components.widget.borderColor}
            onChange={(value) => updateToken('components.widget.borderColor', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.widget.borderColor"
            onReset={() => resetTokenToBaseline('components.widget.borderColor')}
          />
        </div>
      </CollapsibleSection>

      {/* Single Choice Section */}
      <CollapsibleSection 
        title="Single Choice" 
        defaultOpen={false}
        actions={
          <button
            type="button"
            className="reset-group-button"
            onClick={() => handleResetGroup('component')}
            title="Reset all single choice component tokens to baseline"
          >
            Reset Group
          </button>
        }
      >
        <div className="editor-fields">
          <ColorInput
            label="Default Background"
            value={getToken<string>('components.singleChoice.bgDefault') || activeTheme.components.singleChoice.bgDefault}
            onChange={(value) => updateToken('components.singleChoice.bgDefault', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.singleChoice.bgDefault"
            onReset={() => resetTokenToBaseline('components.singleChoice.bgDefault')}
          />
          <ColorInput
            label="Active Background"
            value={getToken<string>('components.singleChoice.bgActive') || activeTheme.components.singleChoice.bgActive}
            onChange={(value) => updateToken('components.singleChoice.bgActive', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.singleChoice.bgActive"
            onReset={() => resetTokenToBaseline('components.singleChoice.bgActive')}
          />
          <ColorInput
            label="Default Text"
            value={getToken<string>('components.singleChoice.textDefault') || activeTheme.components.singleChoice.textDefault}
            onChange={(value) => updateToken('components.singleChoice.textDefault', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.singleChoice.textDefault"
            onReset={() => resetTokenToBaseline('components.singleChoice.textDefault')}
          />
          <ColorInput
            label="Active Text"
            value={getToken<string>('components.singleChoice.textActive') || activeTheme.components.singleChoice.textActive}
            onChange={(value) => updateToken('components.singleChoice.textActive', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.singleChoice.textActive"
            onReset={() => resetTokenToBaseline('components.singleChoice.textActive')}
          />
          <ColorInput
            label="Default Border"
            value={getToken<string>('components.singleChoice.borderDefault') || activeTheme.components.singleChoice.borderDefault}
            onChange={(value) => updateToken('components.singleChoice.borderDefault', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.singleChoice.borderDefault"
            onReset={() => resetTokenToBaseline('components.singleChoice.borderDefault')}
          />
          <ColorInput
            label="Active Border"
            value={getToken<string>('components.singleChoice.borderActive') || activeTheme.components.singleChoice.borderActive}
            onChange={(value) => updateToken('components.singleChoice.borderActive', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.singleChoice.borderActive"
            onReset={() => resetTokenToBaseline('components.singleChoice.borderActive')}
          />
        </div>
      </CollapsibleSection>

      {/* CTA Button Section */}
      <CollapsibleSection 
        title="CTA Button" 
        defaultOpen={false}
        actions={
          <button
            type="button"
            className="reset-group-button"
            onClick={() => handleResetGroup('component')}
            title="Reset all CTA button component tokens to baseline"
          >
            Reset Group
          </button>
        }
      >
        <div className="editor-fields">
          <ColorInput
            label="Background"
            value={getToken<string>('components.ctaButton.bg') || activeTheme.components.ctaButton.bg}
            onChange={(value) => updateToken('components.ctaButton.bg', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.ctaButton.bg"
            onReset={() => resetTokenToBaseline('components.ctaButton.bg')}
          />
          <ColorInput
            label="Text"
            value={getToken<string>('components.ctaButton.text') || activeTheme.components.ctaButton.text}
            onChange={(value) => updateToken('components.ctaButton.text', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.ctaButton.text"
            onReset={() => resetTokenToBaseline('components.ctaButton.text')}
          />
          <ColorInput
            label="Hover Background"
            value={getToken<string>('components.ctaButton.bgHover') || activeTheme.components.ctaButton.bgHover}
            onChange={(value) => updateToken('components.ctaButton.bgHover', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.ctaButton.bgHover"
            onReset={() => resetTokenToBaseline('components.ctaButton.bgHover')}
          />
          <ColorInput
            label="Hover Text"
            value={getToken<string>('components.ctaButton.textHover') || activeTheme.components.ctaButton.textHover}
            onChange={(value) => updateToken('components.ctaButton.textHover', value, { source: 'themeEditor' })}
            extractedColors={extractedColors}
            paletteColors={paletteColors}
            useDropdown={true}
            tokenPath="components.ctaButton.textHover"
            onReset={() => resetTokenToBaseline('components.ctaButton.textHover')}
          />
        </div>
      </CollapsibleSection>

      {/* Layout Section */}
      <CollapsibleSection 
        title="Layout" 
        defaultOpen={false}
        actions={
          <button
            type="button"
            className="reset-group-button"
            onClick={() => handleResetGroup('layout')}
            title="Reset all layout tokens to baseline"
          >
            Reset Group
          </button>
        }
      >
        <div className="editor-fields">
          {/* Phase 4.7: Enhanced Layout Tokens */}
          <h4 style={{ fontSize: 13, fontWeight: 600, marginBottom: 12, marginTop: 8, color: '#374151' }}>Border Radius</h4>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Widget (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('layout.borderRadiusTokens.widget')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('layout.borderRadiusTokens.widget') ?? activeTheme.layout.borderRadiusTokens?.widget ?? activeTheme.layout.borderRadius}
              onChange={(e) => updateToken('layout.borderRadiusTokens.widget', parseInt(e.target.value) || 8, { source: 'themeEditor' })}
            />
            <small style={{ fontSize: 11, color: '#6b7280', marginTop: 4 }}>layout.borderRadiusTokens.widget</small>
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Button (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('layout.borderRadiusTokens.button')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('layout.borderRadiusTokens.button') ?? activeTheme.layout.borderRadiusTokens?.button ?? activeTheme.layout.borderRadius}
              onChange={(e) => updateToken('layout.borderRadiusTokens.button', parseInt(e.target.value) || 8, { source: 'themeEditor' })}
            />
            <small style={{ fontSize: 11, color: '#6b7280', marginTop: 4 }}>layout.borderRadiusTokens.button</small>
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Option (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('layout.borderRadiusTokens.option')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('layout.borderRadiusTokens.option') ?? activeTheme.layout.borderRadiusTokens?.option ?? activeTheme.layout.borderRadius}
              onChange={(e) => updateToken('layout.borderRadiusTokens.option', parseInt(e.target.value) || 8, { source: 'themeEditor' })}
            />
            <small style={{ fontSize: 11, color: '#6b7280', marginTop: 4 }}>layout.borderRadiusTokens.option</small>
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Input (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('layout.borderRadiusTokens.input')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('layout.borderRadiusTokens.input') ?? activeTheme.layout.borderRadiusTokens?.input ?? 4}
              onChange={(e) => updateToken('layout.borderRadiusTokens.input', parseInt(e.target.value) || 4, { source: 'themeEditor' })}
            />
            <small style={{ fontSize: 11, color: '#6b7280', marginTop: 4 }}>layout.borderRadiusTokens.input</small>
          </div>

          <h4 style={{ fontSize: 13, fontWeight: 600, marginBottom: 12, marginTop: 16, color: '#374151' }}>Spacing</h4>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Option Gap (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('layout.spacing.optionGap')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('layout.spacing.optionGap') ?? activeTheme.layout.spacing?.optionGap ?? activeTheme.layout.spacingMd}
              onChange={(e) => updateToken('layout.spacing.optionGap', parseInt(e.target.value) || 12, { source: 'themeEditor' })}
            />
            <small style={{ fontSize: 11, color: '#6b7280', marginTop: 4 }}>layout.spacing.optionGap</small>
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Widget Padding (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('layout.spacing.widgetPadding')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('layout.spacing.widgetPadding') ?? activeTheme.layout.spacing?.widgetPadding ?? 24}
              onChange={(e) => updateToken('layout.spacing.widgetPadding', parseInt(e.target.value) || 24, { source: 'themeEditor' })}
            />
            <small style={{ fontSize: 11, color: '#6b7280', marginTop: 4 }}>layout.spacing.widgetPadding</small>
          </div>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Section Spacing (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('layout.spacing.sectionSpacing')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('layout.spacing.sectionSpacing') ?? activeTheme.layout.spacing?.sectionSpacing ?? 20}
              onChange={(e) => updateToken('layout.spacing.sectionSpacing', parseInt(e.target.value) || 20, { source: 'themeEditor' })}
            />
            <small style={{ fontSize: 11, color: '#6b7280', marginTop: 4 }}>layout.spacing.sectionSpacing</small>
          </div>

          <h4 style={{ fontSize: 13, fontWeight: 600, marginBottom: 12, marginTop: 16, color: '#374151' }}>Max Width</h4>
          <div className="editor-group">
            <div className="editor-label-row">
              <label>Widget (px)</label>
              <button
                type="button"
                className="reset-token-button"
                onClick={() => resetTokenToBaseline('layout.maxWidth.widget')}
                title="Reset to baseline"
              >
                ↺
              </button>
            </div>
            <input
              type="number"
              value={getToken<number>('layout.maxWidth.widget') ?? activeTheme.layout.maxWidth?.widget ?? 420}
              onChange={(e) => updateToken('layout.maxWidth.widget', parseInt(e.target.value) || 420, { source: 'themeEditor' })}
            />
            <small style={{ fontSize: 11, color: '#6b7280', marginTop: 4 }}>layout.maxWidth.widget</small>
          </div>
        </div>
      </CollapsibleSection>
    </div>
  );
}
