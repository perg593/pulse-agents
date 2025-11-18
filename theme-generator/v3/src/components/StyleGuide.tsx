import { useState } from 'react';
import { useThemeStore } from '../stores/themeStore';
import { getContrastRatio, getContrastStatus } from '../utils/contrast';
import { buildStyleGuideHtml, buildStyleGuideMarkdown } from '../utils/styleGuideExport';
import { compileTheme } from '../theme/compileTheme';
import { getToken } from '../theme/tokenManager';

export function StyleGuide() {
  const activeTheme = useThemeStore((state) => state.getActiveTheme());
  const activeProject = useThemeStore((state) => state.getActiveProject());
  const [copied, setCopied] = useState<'html' | 'markdown' | null>(null);

  if (!activeTheme || !activeProject) {
    return (
      <div className="style-guide">
        <div className="style-guide-header">
          <h2>Style Guide</h2>
        </div>
        <div className="style-guide-empty">
          <p>Select a theme to view its style guide.</p>
        </div>
      </div>
    );
  }

  const { palette, typography, components } = activeTheme; // Phase 4.7: Layout tokens used via compiledCSS

  // Phase 4.4: Use getToken for reads where practical
  // Calculate contrast ratios
  const textPrimary = getToken<string>('palette.textPrimary') || palette.textPrimary;
  const background = getToken<string>('palette.background') || palette.background;
  const surface = getToken<string>('palette.surface') || palette.surface;
  const ctaButtonText = getToken<string>('components.ctaButton.text') || components.ctaButton.text;
  const ctaButtonBg = getToken<string>('components.ctaButton.bg') || components.ctaButton.bg;
  const singleChoiceTextActive = getToken<string>('components.singleChoice.textActive') || components.singleChoice.textActive;
  const singleChoiceBgActive = getToken<string>('components.singleChoice.bgActive') || components.singleChoice.bgActive;

  const textOnBgRatio = getContrastRatio(textPrimary, background);
  const textOnSurfaceRatio = getContrastRatio(textPrimary, surface);
  const ctaRatio = getContrastRatio(ctaButtonText, ctaButtonBg);
  const singleChoiceRatio = getContrastRatio(singleChoiceTextActive, singleChoiceBgActive);

  const textOnBgStatus = getContrastStatus(textOnBgRatio);
  const textOnSurfaceStatus = getContrastStatus(textOnSurfaceRatio);
  const ctaStatus = getContrastStatus(ctaRatio);
  const singleChoiceStatus = getContrastStatus(singleChoiceRatio);

  // Get compiled CSS for component samples
  const compiledCSS = compileTheme(activeTheme);

  const handleCopyHtml = async () => {
    const html = buildStyleGuideHtml(activeTheme, activeProject);
    await navigator.clipboard.writeText(html);
    setCopied('html');
    setTimeout(() => setCopied(null), 2000);
  };

  const handleCopyMarkdown = async () => {
    const markdown = buildStyleGuideMarkdown(activeTheme, activeProject);
    await navigator.clipboard.writeText(markdown);
    setCopied('markdown');
    setTimeout(() => setCopied(null), 2000);
  };

  // Phase 4.3: Color Palette in spec order
  // Phase 4.4: Use getToken for reads
  const colorSwatches = [
    { name: 'Brand Primary', value: getToken<string>('palette.brandPrimary') || palette.brandPrimary, token: 'palette.brandPrimary' },
    { name: 'Brand Secondary', value: getToken<string>('palette.brandSecondary') || palette.brandSecondary, token: 'palette.brandSecondary' },
    { name: 'Accent', value: getToken<string>('palette.accent') || palette.accent, token: 'palette.accent' },
    { name: 'Background', value: background, token: 'palette.background' },
    { name: 'Surface', value: surface, token: 'palette.surface' },
    { name: 'Text Primary', value: textPrimary, token: 'palette.textPrimary' },
    { name: 'Text Secondary', value: getToken<string>('palette.textSecondary') || palette.textSecondary, token: 'palette.textSecondary' },
    { name: 'Success', value: getToken<string>('palette.success') || palette.success, token: 'palette.success' },
    { name: 'Danger', value: getToken<string>('palette.danger') || palette.danger, token: 'palette.danger' }
  ];

  return (
    <div className="style-guide">
      <div className="style-guide-header">
        <div className="style-guide-header-content">
          <div>
            <h1 className="style-guide-theme-name">{activeTheme.name}</h1>
            <p className="style-guide-meta">
              {activeProject.name} · {activeTheme.variantType}
            </p>
          </div>
          <div className="style-guide-export-actions">
            <button
              className="btn-export"
              onClick={handleCopyMarkdown}
              disabled={copied === 'markdown'}
            >
              {copied === 'markdown' ? '✓ Copied!' : 'Copy Markdown'}
            </button>
            <button
              className="btn-export"
              onClick={handleCopyHtml}
              disabled={copied === 'html'}
            >
              {copied === 'html' ? '✓ Copied!' : 'Copy HTML'}
            </button>
          </div>
        </div>
      </div>

      <div className="style-guide-content">
        {/* Phase 4.3: Color Palette Section */}
        <section className="style-guide-section">
          <h3>Color Palette</h3>
          <div className="color-grid">
            {colorSwatches.map((swatch) => (
              <div key={swatch.token} className="color-swatch">
                <div
                  className="color-chip"
                  style={{ backgroundColor: swatch.value }}
                />
                <div className="color-info">
                  <div className="color-name">{swatch.name}</div>
                  <div className="color-value">{swatch.value}</div>
                  <div className="color-token">{swatch.token}</div>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* Phase 4.3: Typography Section */}
        {/* Phase 4.7: Updated to use enhanced typography tokens */}
        <section className="style-guide-section">
          <h3>Typography</h3>
          <div className="typography-samples">
            <div className="typography-sample">
              <div className="typography-label">Heading</div>
              <div
                className="typography-heading"
                style={{
                  fontFamily: getToken<string>('typography.heading.fontFamily') || typography.heading?.fontFamily || typography.fontFamilyHeading || typography.fontFamilyBase,
                  fontSize: `${getToken<number>('typography.heading.fontSize') ?? typography.heading?.fontSize ?? typography.headingSize}px`,
                  fontWeight: getToken<number>('typography.heading.fontWeight') ?? typography.heading?.fontWeight ?? 600,
                  lineHeight: getToken<number>('typography.heading.lineHeight') ?? typography.heading?.lineHeight ?? 1.3,
                  color: palette.textPrimary
                }}
              >
                Quick Feedback Survey
              </div>
              <div className="typography-meta">
                {getToken<number>('typography.heading.fontSize') ?? typography.heading?.fontSize ?? typography.headingSize}px / {(getToken<string>('typography.heading.fontFamily') || typography.heading?.fontFamily || typography.fontFamilyHeading || typography.fontFamilyBase).split(',')[0]} / {getToken<number>('typography.heading.fontWeight') ?? typography.heading?.fontWeight ?? 600}
              </div>
              <div className="typography-token">typography.heading.*</div>
            </div>
            <div className="typography-sample">
              <div className="typography-label">Body</div>
              <div
                className="typography-body"
                style={{
                  fontFamily: getToken<string>('typography.body.fontFamily') || typography.body?.fontFamily || typography.fontFamilyBase,
                  fontSize: `${getToken<number>('typography.body.fontSize') ?? typography.body?.fontSize ?? typography.bodySize}px`,
                  fontWeight: getToken<number>('typography.body.fontWeight') ?? typography.body?.fontWeight ?? 400,
                  lineHeight: getToken<number>('typography.body.lineHeight') ?? typography.body?.lineHeight ?? 1.5,
                  color: palette.textPrimary
                }}
              >
                How satisfied are you with our service?
              </div>
              <div className="typography-meta">
                {getToken<number>('typography.body.fontSize') ?? typography.body?.fontSize ?? typography.bodySize}px / {(getToken<string>('typography.body.fontFamily') || typography.body?.fontFamily || typography.fontFamilyBase).split(',')[0]} / {getToken<number>('typography.body.fontWeight') ?? typography.body?.fontWeight ?? 400}
              </div>
              <div className="typography-token">typography.body.*</div>
            </div>
            <div className="typography-sample">
              <div className="typography-label">Button</div>
              <div
                className="typography-button"
                style={{
                  fontFamily: getToken<string>('typography.button.fontFamily') || typography.button?.fontFamily || typography.fontFamilyBase,
                  fontSize: `${getToken<number>('typography.button.fontSize') ?? typography.button?.fontSize ?? typography.buttonSize}px`,
                  fontWeight: getToken<number>('typography.button.fontWeight') ?? typography.button?.fontWeight ?? 600,
                  lineHeight: getToken<number>('typography.button.lineHeight') ?? typography.button?.lineHeight ?? 1.4,
                  letterSpacing: `${getToken<number>('typography.button.letterSpacing') ?? typography.button?.letterSpacing ?? 0.5}px`,
                  color: components.ctaButton.text
                }}
              >
                Submit Feedback
              </div>
              <div className="typography-meta">
                {getToken<number>('typography.button.fontSize') ?? typography.button?.fontSize ?? typography.buttonSize}px / {(getToken<string>('typography.button.fontFamily') || typography.button?.fontFamily || typography.fontFamilyBase).split(',')[0]} / {getToken<number>('typography.button.fontWeight') ?? typography.button?.fontWeight ?? 600}
              </div>
              <div className="typography-token">typography.button.*</div>
            </div>
          </div>
        </section>

        {/* Phase 4.3: Components Section */}
        <section className="style-guide-section">
          <h3>Components</h3>
          <div className="component-samples">
            <style dangerouslySetInnerHTML={{ __html: compiledCSS }} />
            
            {/* Single Choice - Default and Active side-by-side */}
            <div className="component-sample">
              <div className="component-label">Single Choice Option</div>
              <div className="component-preview-row">
                <div className="component-preview-item">
                  <div className="component-preview-label">Default</div>
                  <ul className="_pi_answers_container" style={{ margin: 0 }}>
                    <li>
                      <a href="#" style={{ pointerEvents: 'none' }}>Option 1</a>
                    </li>
                  </ul>
                </div>
                <div className="component-preview-item">
                  <div className="component-preview-label">Active</div>
                  <ul className="_pi_answers_container" style={{ margin: 0 }}>
                    <li 
                      className="active"
                      style={{ 
                        backgroundColor: components.singleChoice.bgActive,
                        borderColor: components.singleChoice.borderActive
                      }}
                    >
                      <a 
                        href="#" 
                        style={{ 
                          color: components.singleChoice.textActive,
                          pointerEvents: 'none'
                        }}
                      >
                        Option 2
                      </a>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
            
            {/* CTA Button */}
            <div className="component-sample">
              <div className="component-label">CTA Button</div>
              <input
                type="button"
                className="_pi_all_questions_submit_button"
                value="Submit Feedback"
                readOnly
                style={{ pointerEvents: 'none', cursor: 'default' }}
              />
            </div>
            
            {/* Text Input */}
            <div className="component-sample">
              <div className="component-label">Text Input</div>
              <input
                type="text"
                className="_pi_free_text_question_field"
                placeholder="Enter your answer…"
                readOnly
                style={{ pointerEvents: 'none', cursor: 'default' }}
              />
            </div>
          </div>
        </section>

        {/* Phase 4.3: Accessibility / Contrast Summary */}
        <section className="style-guide-section">
          <h3>Accessibility / Contrast Summary</h3>
          <div className="contrast-table">
            <table>
              <thead>
                <tr>
                  <th>Color Pair</th>
                  <th>Swatches</th>
                  <th>Contrast Ratio</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Text Primary vs Background</td>
                  <td>
                    <div className="contrast-swatches">
                      <div 
                        className="contrast-swatch" 
                        style={{ backgroundColor: textPrimary }}
                        title="Text Primary"
                      />
                      <div 
                        className="contrast-swatch" 
                        style={{ backgroundColor: background }}
                        title="Background"
                      />
                    </div>
                  </td>
                  <td>{textOnBgRatio.toFixed(2)}:1</td>
                  <td>
                    <span className={`contrast-status ${textOnBgStatus.status}`}>
                      {textOnBgStatus.status === 'fail' ? '⚠️' : '✅'} {textOnBgStatus.status === 'fail' ? 'Low contrast – consider adjusting' : 'Pass (AA normal text)'}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td>Text Primary vs Surface</td>
                  <td>
                    <div className="contrast-swatches">
                      <div 
                        className="contrast-swatch" 
                        style={{ backgroundColor: textPrimary }}
                        title="Text Primary"
                      />
                      <div 
                        className="contrast-swatch" 
                        style={{ backgroundColor: surface }}
                        title="Surface"
                      />
                    </div>
                  </td>
                  <td>{textOnSurfaceRatio.toFixed(2)}:1</td>
                  <td>
                    <span className={`contrast-status ${textOnSurfaceStatus.status}`}>
                      {textOnSurfaceStatus.status === 'fail' ? '⚠️' : '✅'} {textOnSurfaceStatus.status === 'fail' ? 'Low contrast – consider adjusting' : 'Pass (AA normal text)'}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td>CTA Button Text vs CTA Button Background</td>
                  <td>
                    <div className="contrast-swatches">
                      <div 
                        className="contrast-swatch" 
                        style={{ backgroundColor: ctaButtonText }}
                        title="CTA Button Text"
                      />
                      <div 
                        className="contrast-swatch" 
                        style={{ backgroundColor: ctaButtonBg }}
                        title="CTA Button Background"
                      />
                    </div>
                  </td>
                  <td>{ctaRatio.toFixed(2)}:1</td>
                  <td>
                    <span className={`contrast-status ${ctaStatus.status}`}>
                      {ctaStatus.status === 'fail' ? '⚠️' : '✅'} {ctaStatus.status === 'fail' ? 'Low contrast – consider adjusting' : 'Pass (AA normal text)'}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td>Single Choice Active Text vs Active Background</td>
                  <td>
                    <div className="contrast-swatches">
                      <div 
                        className="contrast-swatch" 
                        style={{ backgroundColor: singleChoiceTextActive }}
                        title="Single Choice Active Text"
                      />
                      <div 
                        className="contrast-swatch" 
                        style={{ backgroundColor: singleChoiceBgActive }}
                        title="Single Choice Active Background"
                      />
                    </div>
                  </td>
                  <td>{singleChoiceRatio.toFixed(2)}:1</td>
                  <td>
                    <span className={`contrast-status ${singleChoiceStatus.status}`}>
                      {singleChoiceStatus.status === 'fail' ? '⚠️' : '✅'} {singleChoiceStatus.status === 'fail' ? 'Low contrast – consider adjusting' : 'Pass (AA normal text)'}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </div>
  );
}

