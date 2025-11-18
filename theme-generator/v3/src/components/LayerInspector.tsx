/**
 * Phase 4.0: Layer Inspector Panel
 * Shows selected layer info and centralized palette for quick editing
 * Phase 4.4: Refactored to use Token Manager
 */

import { useThemeStore } from '../stores/themeStore';
import { updateToken, getToken, resetTokenToBaseline } from '../theme/tokenManager'; // Phase 4.6: Import resetTokenToBaseline
import type { LayerDefinition } from '../types/layers';

interface LayerInspectorProps {
  layer: LayerDefinition | null;
  onClose?: () => void;
}

export function LayerInspector({ layer, onClose }: LayerInspectorProps) {
  const activeTheme = useThemeStore((state) => state.getActiveTheme());

  if (!layer || !activeTheme) {
    return null;
  }

  // Phase 4.1: Get centralized brand palette colors (matching spec)
  // Phase 4.4: Use getToken for reads
  const paletteColors = [
    { name: 'Brand Primary', path: 'palette.brandPrimary', color: getToken<string>('palette.brandPrimary') || activeTheme.palette.brandPrimary },
    { name: 'Brand Secondary', path: 'palette.brandSecondary', color: getToken<string>('palette.brandSecondary') || activeTheme.palette.brandSecondary },
    { name: 'Accent', path: 'palette.accent', color: getToken<string>('palette.accent') || activeTheme.palette.accent },
    { name: 'Background', path: 'palette.background', color: getToken<string>('palette.background') || activeTheme.palette.background },
    { name: 'Surface', path: 'palette.surface', color: getToken<string>('palette.surface') || activeTheme.palette.surface },
    { name: 'Text Primary', path: 'palette.textPrimary', color: getToken<string>('palette.textPrimary') || activeTheme.palette.textPrimary },
    { name: 'Text Secondary', path: 'palette.textSecondary', color: getToken<string>('palette.textSecondary') || activeTheme.palette.textSecondary }
  ];
  
  // Get current color for the first mapping (for display)
  // Phase 4.4: Use getToken for reads
  const firstMapping = layer.mappings[0];
  const currentColor = firstMapping ? getToken<string>(firstMapping.tokenPath) : undefined;

  // Phase 4.7: Detect if this is a text-related or container-related layer
  const isTextLayer = layer.id.includes('header') || layer.id.includes('text') || 
                      layer.id.includes('single-choice') || layer.id.includes('button-text');
  const isContainerLayer = layer.id.includes('container') || layer.id.includes('widget-body') || 
                          layer.id.includes('cta-button-bg') || layer.id.includes('single-choice');

  // Phase 4.7: Get typography tokens for text layers
  const headingFontFamily = getToken<string>('typography.heading.fontFamily') || activeTheme.typography.heading?.fontFamily || activeTheme.typography.fontFamilyHeading || activeTheme.typography.fontFamilyBase;
  const headingFontSize = getToken<number>('typography.heading.fontSize') ?? activeTheme.typography.heading?.fontSize ?? activeTheme.typography.headingSize;
  const headingFontWeight = getToken<number>('typography.heading.fontWeight') ?? activeTheme.typography.heading?.fontWeight ?? 600;
  const bodyFontFamily = getToken<string>('typography.body.fontFamily') || activeTheme.typography.body?.fontFamily || activeTheme.typography.fontFamilyBase;
  const bodyFontSize = getToken<number>('typography.body.fontSize') ?? activeTheme.typography.body?.fontSize ?? activeTheme.typography.bodySize;
  const bodyFontWeight = getToken<number>('typography.body.fontWeight') ?? activeTheme.typography.body?.fontWeight ?? 400;
  const buttonFontFamily = getToken<string>('typography.button.fontFamily') || activeTheme.typography.button?.fontFamily || activeTheme.typography.fontFamilyBase;
  const buttonFontSize = getToken<number>('typography.button.fontSize') ?? activeTheme.typography.button?.fontSize ?? activeTheme.typography.buttonSize;
  const buttonFontWeight = getToken<number>('typography.button.fontWeight') ?? activeTheme.typography.button?.fontWeight ?? 600;

  // Phase 4.7: Get layout tokens for container layers
  const widgetBorderRadius = getToken<number>('layout.borderRadiusTokens.widget') ?? activeTheme.layout.borderRadiusTokens?.widget ?? activeTheme.layout.borderRadius;
  const buttonBorderRadius = getToken<number>('layout.borderRadiusTokens.button') ?? activeTheme.layout.borderRadiusTokens?.button ?? activeTheme.layout.borderRadius;
  const optionBorderRadius = getToken<number>('layout.borderRadiusTokens.option') ?? activeTheme.layout.borderRadiusTokens?.option ?? activeTheme.layout.borderRadius;
  const widgetPadding = getToken<number>('layout.spacing.widgetPadding') ?? activeTheme.layout.spacing?.widgetPadding ?? 24;
  const optionGap = getToken<number>('layout.spacing.optionGap') ?? activeTheme.layout.spacing?.optionGap ?? activeTheme.layout.spacingMd;
  const widgetMaxWidth = getToken<number>('layout.maxWidth.widget') ?? activeTheme.layout.maxWidth?.widget ?? 420;

  const handleColorClick = (_tokenPath: string, color: string) => {
    // Phase 4.4: Update all mappings for this layer using updateToken
    layer.mappings.forEach(mapping => {
      updateToken(mapping.tokenPath, color, { source: 'layerInspector' });
    });
  };

  const handleJumpToTypography = () => {
    const editor = document.querySelector('.theme-editor');
    if (!editor) return;
    
    const sections = editor.querySelectorAll('.collapsible-section');
    const typographySection = Array.from(sections).find(s => {
      const title = s.querySelector('.collapsible-title');
      return title?.textContent === 'Typography';
    });
    
    if (typographySection) {
      typographySection.scrollIntoView({ behavior: 'smooth', block: 'start' });
      // Try to expand the section if collapsed
      const header = typographySection.querySelector('.collapsible-header') as HTMLElement;
      const content = typographySection.querySelector('.collapsible-content');
      if (header && !content) {
        header.click();
      }
    }
  };

  const handleJumpToLayout = () => {
    const editor = document.querySelector('.theme-editor');
    if (!editor) return;
    
    const sections = editor.querySelectorAll('.collapsible-section');
    const layoutSection = Array.from(sections).find(s => {
      const title = s.querySelector('.collapsible-title');
      return title?.textContent === 'Layout';
    });
    
    if (layoutSection) {
      layoutSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
      // Try to expand the section if collapsed
      const header = layoutSection.querySelector('.collapsible-header') as HTMLElement;
      const content = layoutSection.querySelector('.collapsible-content');
      if (header && !content) {
        header.click();
      }
    }
  };

  return (
    <div className="layer-inspector">
      <div className="layer-inspector-header">
        <h3 className="layer-inspector-title">{layer.displayName}</h3>
        {onClose && (
          <button
            type="button"
            className="layer-inspector-close"
            onClick={onClose}
            aria-label="Close inspector"
          >
            ×
          </button>
        )}
      </div>
      
      <div className="layer-inspector-content">
        <div className="layer-token-mappings">
          <div className="mappings-label">Mapped Tokens:</div>
          {layer.mappings.map((mapping, index) => {
            // Phase 4.4: Use getToken for reads
            const currentValue = getToken<string>(mapping.tokenPath);
            return (
              <div key={index} className="token-mapping">
                <code className="token-path">{mapping.tokenPath}</code>
                <span className="token-role">({mapping.role})</span>
                {currentValue && (
                  <span className="token-value" style={{ color: currentValue }}>
                    {currentValue}
                  </span>
                )}
              </div>
            );
          })}
        </div>
        
        <div className="layer-palette">
          <div className="palette-label">Brand Palette:</div>
          <div className="palette-swatches">
            {paletteColors.map((paletteColor) => (
              <button
                key={paletteColor.path}
                type="button"
                className="palette-swatch"
                style={{ backgroundColor: paletteColor.color }}
                onClick={() => handleColorClick(paletteColor.path, paletteColor.color)}
                title={paletteColor.name}
              />
            ))}
          </div>
          
          {/* Phase 4.1: Current color + custom hex input */}
          {currentColor && (
            <div className="layer-current-color">
              <div className="current-color-label">Current Color:</div>
              <div className="current-color-display">
                <div 
                  className="current-color-swatch"
                  style={{ backgroundColor: currentColor }}
                />
                <input
                  type="text"
                  className="current-color-input"
                  value={currentColor}
                  onChange={(e) => {
                    const newColor = e.target.value;
                    if (/^#[0-9A-Fa-f]{6}$/.test(newColor)) {
                      // Phase 4.4: Use updateToken
                      layer.mappings.forEach(mapping => {
                        updateToken(mapping.tokenPath, newColor, { source: 'layerInspector' });
                      });
                    }
                  }}
                  placeholder="#000000"
                />
                {firstMapping && (
                  <button
                    type="button"
                    className="reset-token-button"
                    onClick={() => resetTokenToBaseline(firstMapping.tokenPath)}
                    title="Reset to baseline"
                  >
                    ↺
                  </button>
                )}
              </div>
            </div>
          )}
          
          <button
            type="button"
            className="palette-more-button"
            onClick={() => {
              // Scroll to Theme Editor for full color picker
              const editor = document.querySelector('.theme-editor');
              if (editor) {
                editor.scrollIntoView({ behavior: 'smooth', block: 'start' });
              }
            }}
          >
            More…
          </button>
        </div>

        {/* Phase 4.7: Typography info for text-related layers */}
        {isTextLayer && (
          <div className="layer-typography">
            <div className="typography-label">Typography:</div>
            {layer.id.includes('header') && (
              <div className="typography-info">
                <div className="typography-sample" style={{
                  fontFamily: headingFontFamily,
                  fontSize: `${headingFontSize}px`,
                  fontWeight: headingFontWeight,
                  color: getToken<string>('components.widget.headerText') || activeTheme.components.widget.headerText
                }}>
                  Sample Heading Text
                </div>
                <div className="typography-meta">
                  {headingFontSize}px / {headingFontFamily.split(',')[0]} / {headingFontWeight}
                </div>
                <div className="typography-tokens">
                  <code>typography.heading.*</code>
                </div>
                <button
                  type="button"
                  className="jump-to-section-button"
                  onClick={handleJumpToTypography}
                >
                  Jump to Typography Editor
                </button>
              </div>
            )}
            {(layer.id.includes('single-choice') || layer.id.includes('text-input')) && (
              <div className="typography-info">
                <div className="typography-sample" style={{
                  fontFamily: bodyFontFamily,
                  fontSize: `${bodyFontSize}px`,
                  fontWeight: bodyFontWeight,
                  color: getToken<string>('palette.textPrimary') || activeTheme.palette.textPrimary
                }}>
                  Sample Body Text
                </div>
                <div className="typography-meta">
                  {bodyFontSize}px / {bodyFontFamily.split(',')[0]} / {bodyFontWeight}
                </div>
                <div className="typography-tokens">
                  <code>typography.body.*</code>
                </div>
                <button
                  type="button"
                  className="jump-to-section-button"
                  onClick={handleJumpToTypography}
                >
                  Jump to Typography Editor
                </button>
              </div>
            )}
            {layer.id.includes('cta-button-text') && (
              <div className="typography-info">
                <div className="typography-sample" style={{
                  fontFamily: buttonFontFamily,
                  fontSize: `${buttonFontSize}px`,
                  fontWeight: buttonFontWeight,
                  color: getToken<string>('components.ctaButton.text') || activeTheme.components.ctaButton.text
                }}>
                  Submit Feedback
                </div>
                <div className="typography-meta">
                  {buttonFontSize}px / {buttonFontFamily.split(',')[0]} / {buttonFontWeight}
                </div>
                <div className="typography-tokens">
                  <code>typography.button.*</code>
                </div>
                <button
                  type="button"
                  className="jump-to-section-button"
                  onClick={handleJumpToTypography}
                >
                  Jump to Typography Editor
                </button>
              </div>
            )}
          </div>
        )}

        {/* Phase 4.7: Layout info for container-related layers */}
        {isContainerLayer && (
          <div className="layer-layout">
            <div className="layout-label">Layout:</div>
            {layer.id.includes('widget-container') || layer.id.includes('widget-body') ? (
              <div className="layout-info">
                <div className="layout-item">
                  <span className="layout-item-label">Border Radius:</span>
                  <span className="layout-item-value">{widgetBorderRadius}px</span>
                  <code className="layout-item-token">layout.borderRadiusTokens.widget</code>
                </div>
                <div className="layout-item">
                  <span className="layout-item-label">Padding:</span>
                  <span className="layout-item-value">{widgetPadding}px</span>
                  <code className="layout-item-token">layout.spacing.widgetPadding</code>
                </div>
                <div className="layout-item">
                  <span className="layout-item-label">Max Width:</span>
                  <span className="layout-item-value">{widgetMaxWidth}px</span>
                  <code className="layout-item-token">layout.maxWidth.widget</code>
                </div>
                <button
                  type="button"
                  className="jump-to-section-button"
                  onClick={handleJumpToLayout}
                >
                  Jump to Layout Editor
                </button>
              </div>
            ) : layer.id.includes('single-choice') ? (
              <div className="layout-info">
                <div className="layout-item">
                  <span className="layout-item-label">Border Radius:</span>
                  <span className="layout-item-value">{optionBorderRadius}px</span>
                  <code className="layout-item-token">layout.borderRadiusTokens.option</code>
                </div>
                <div className="layout-item">
                  <span className="layout-item-label">Gap:</span>
                  <span className="layout-item-value">{optionGap}px</span>
                  <code className="layout-item-token">layout.spacing.optionGap</code>
                </div>
                <button
                  type="button"
                  className="jump-to-section-button"
                  onClick={handleJumpToLayout}
                >
                  Jump to Layout Editor
                </button>
              </div>
            ) : layer.id.includes('cta-button') ? (
              <div className="layout-info">
                <div className="layout-item">
                  <span className="layout-item-label">Border Radius:</span>
                  <span className="layout-item-value">{buttonBorderRadius}px</span>
                  <code className="layout-item-token">layout.borderRadiusTokens.button</code>
                </div>
                <button
                  type="button"
                  className="jump-to-section-button"
                  onClick={handleJumpToLayout}
                >
                  Jump to Layout Editor
                </button>
              </div>
            ) : null}
          </div>
        )}
      </div>
    </div>
  );
}

