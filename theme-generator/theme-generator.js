const fs = require('fs');
const path = require('path');
const {
  compileTheme,
  parseColor: parseThemeColor,
  contrastRatio: computeContrast
} = require('./src/theme-css.js');

class SimpleThemeGenerator {
  constructor(analysis = {}) {
    const fonts = analysis?.fonts || {};
    this.analysis = {
      ...analysis,
      colors: { ...(analysis?.colors || {}) },
      fonts: {
        families: Array.isArray(fonts.families) ? fonts.families : [],
        sizes: Array.isArray(fonts.sizes) ? fonts.sizes : [],
        weights: Array.isArray(fonts.weights) ? fonts.weights : []
      }
    };
  }

  extractRootColorCandidates() {
    const rootVars = this.analysis.colors?.rootVariables || {};
    const buckets = {
      primary: [],
      secondary: [],
      accent: [],
      background: [],
      text: [],
      border: []
    };
    Object.entries(rootVars).forEach(([name, value]) => {
      if (!value || typeof value !== 'string') return;
      const trimmed = value.trim();
      if (!trimmed || trimmed.includes('var(')) return;
      const normalized = this.normalizeColorValue(trimmed);
      if (!normalized) return;
      const key = name.toLowerCase();
      if (key.includes('primary')) buckets.primary.push(normalized);
      if (key.includes('secondary')) buckets.secondary.push(normalized);
      if (key.includes('accent') || key.includes('brand') || key.includes('highlight')) {
        buckets.accent.push(normalized);
      }
      if (key.includes('background') || key.includes('surface') || key.includes('panel') || key.includes('card')) {
        buckets.background.push(normalized);
      }
      if (key.includes('text') || key.includes('font') || key.includes('body')) {
        buckets.text.push(normalized);
      }
      if (key.includes('border') || key.includes('stroke') || key.includes('outline')) {
        buckets.border.push(normalized);
      }
    });
    return buckets;
  }

  generateThemes() {
    console.log('🎨 Generating theme variations...');

    const themes = [
      this.generateBrandFaithfulTheme(),
      this.generateHighContrastTheme(),
      this.generateModernTheme(),
      this.generateMinimalistTheme()
    ].map(theme => {
      const tokens = this.buildThemeTokens(theme.config, { name: theme.name, variant: theme.variant });
      const overrides = this.buildVariantOverrides(theme.variant, tokens);
      return {
        ...theme,
        tokens,
        overrides
      };
    });

    console.log(`✅ Generated ${themes.length} theme variations`);
    return themes;
  }

  getFontFamilyWithFallbacks(fontName) {
    if (!fontName) {
      return 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';
    }

    if (fontName.includes(',') && fontName.includes('sans-serif')) {
      return fontName;
    }

    const trimmed = fontName.replace(/['"]/g, '').trim();
    const fallbacks =
      'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';
    return `"${trimmed}", ${fallbacks}`;
  }

  generateBrandFaithfulTheme() {
    const isAirSupra = (this.analysis.url || '').includes('airsupra');
    const fontFamily = this.getFontFamilyWithFallbacks(this.analysis.fonts.families[0]);
    const colors = this.analysis.colors || {};

    if (isAirSupra) {
      return {
        name: 'Brand Faithful',
        description: "Matches AirSupra's brand colors and fonts",
        config: {
          '--pi-primary-color': '#ff6b35',
          '--pi-secondary-color': '#1e3a8a',
          '--pi-text-color': '#1f2937',
          '--pi-background-color': '#ffffff',
          '--pi-border-color': '#e5e7eb',
          '--pi-hover-color': '#dc2626',
          '--pi-font-family': fontFamily,
          '--pi-border-radius': '8px',
          '--pi-box-shadow': '0 4px 12px rgba(0,0,0,0.15)'
        }
      };
    }

    const detectedColors = this.detectBrandColors(colors);

    return {
      name: 'Brand Faithful',
      description: "Matches the client's brand colors and fonts",
      variant: 'brand',
      config: {
        '--pi-primary-color': detectedColors.primary,
        '--pi-secondary-color': detectedColors.secondary,
        '--pi-text-color': detectedColors.text,
        '--pi-background-color': detectedColors.background,
        '--pi-border-color': detectedColors.border,
        '--pi-hover-color': detectedColors.hover,
        '--pi-font-family': fontFamily,
        '--pi-border-radius': '8px',
        '--pi-box-shadow': '0 4px 12px rgba(0,0,0,0.15)'
      }
    };
  }

  detectBrandColors(colors = {}) {
    const rootCandidates = this.extractRootColorCandidates();
    const accentColors = Array.isArray(colors.accentColors) ? colors.accentColors.filter(Boolean) : [];
    const backgroundCandidates = Array.isArray(colors.backgrounds) ? colors.backgrounds.filter(Boolean) : [];
    const textCandidates = Array.isArray(colors.textColors) ? colors.textColors.filter(Boolean) : [];
    const borderCandidates = Array.isArray(colors.borderColors) ? colors.borderColors.filter(Boolean) : [];

    if (rootCandidates.accent.length) {
      accentColors.unshift(...rootCandidates.accent);
    }
    if (rootCandidates.background.length) {
      backgroundCandidates.unshift(...rootCandidates.background);
    }
    if (rootCandidates.text.length) {
      textCandidates.unshift(...rootCandidates.text);
    }
    if (rootCandidates.border.length) {
      borderCandidates.unshift(...rootCandidates.border);
    }

    let primaryColor = '#007bff';
    let secondaryColor = '#6b7280';
    let textColor = '#1f2937';
    let backgroundColor = '#ffffff';
    let borderColor = '#e5e7eb';
    let hoverColor = '#0056b3';

    if (accentColors.length > 0) {
      primaryColor = accentColors[0];
      if (accentColors.length > 1) {
        secondaryColor = accentColors[1];
      }
    } else if (backgroundCandidates.length > 0) {
      primaryColor = backgroundCandidates[0];
      if (backgroundCandidates.length > 1) {
        secondaryColor = backgroundCandidates[1];
      }
    }

    if (textCandidates.length > 0) {
      textColor = textCandidates[0];
    }

    if (borderCandidates.length > 0) {
      borderColor = borderCandidates[0];
    }

    primaryColor = this.normalizeColorValue(primaryColor, '#007bff');
    secondaryColor = this.normalizeColorValue(secondaryColor, '#6b7280');
    textColor = this.normalizeColorValue(textColor, '#1f2937');
    backgroundColor = this.normalizeColorValue(backgroundColor, '#ffffff');
    borderColor = this.normalizeColorValue(borderColor, this.lightenColor(primaryColor, 40));
    hoverColor = this.normalizeColorValue(this.darkenColor(primaryColor, 15), this.darkenColor(primaryColor, 15));

    return {
      primary: primaryColor,
      secondary: secondaryColor,
      text: textColor,
      background: backgroundColor,
      border: borderColor,
      hover: hoverColor
    };
  }

  generateHighContrastTheme() {
    const colors = this.analysis.colors || {};
    const accentColors = Array.isArray(colors.accentColors) ? colors.accentColors.filter(Boolean) : [];
    const backgroundCandidates = Array.isArray(colors.backgrounds) ? colors.backgrounds.filter(Boolean) : [];
    const brandColor = accentColors[0] || backgroundCandidates[0] || '#000000';
    const fontFamily = this.getFontFamilyWithFallbacks(this.analysis.fonts.families[0]);

    return {
      name: 'High Contrast',
      description: 'High contrast for accessibility compliance',
      variant: 'high-contrast',
      config: {
        '--pi-primary-color': '#000000',
        '--pi-secondary-color': '#ffffff',
        '--pi-text-color': '#000000',
        '--pi-background-color': '#ffffff',
        '--pi-border-color': '#000000',
        '--pi-hover-color': brandColor,
        '--pi-font-family': fontFamily,
        '--pi-border-radius': '4px',
        '--pi-box-shadow': '0 2px 8px rgba(0,0,0,0.3)'
      }
    };
  }

  generateModernTheme() {
    const colors = this.analysis.colors || {};
    const accentColors = Array.isArray(colors.accentColors) ? colors.accentColors.filter(Boolean) : [];
    const backgroundCandidates = Array.isArray(colors.backgrounds) ? colors.backgrounds.filter(Boolean) : [];
    const brandPrimary = accentColors[0] || backgroundCandidates[0] || '#6366f1';
    const brandSecondary = accentColors[1] || backgroundCandidates[1] || '#8b5cf6';
    const fontFamily = this.getFontFamilyWithFallbacks(this.analysis.fonts.families[0]);

    const modernPrimary = this.modernizeColor(brandPrimary);
    const modernSecondary = this.modernizeColor(brandSecondary);

    return {
      name: 'Modern',
      description: 'Contemporary design with modern colors',
      variant: 'modern',
      config: {
        '--pi-primary-color': modernPrimary,
        '--pi-secondary-color': modernSecondary,
        '--pi-text-color': '#1f2937',
        '--pi-background-color': '#ffffff',
        '--pi-border-color': '#e5e7eb',
        '--pi-hover-color': this.darkenColor(modernPrimary, 10),
        '--pi-font-family': fontFamily,
        '--pi-border-radius': '12px',
        '--pi-box-shadow': '0 10px 25px rgba(0,0,0,0.1)'
      }
    };
  }

  generateMinimalistTheme() {
    return {
      name: 'Minimalist',
      description: 'Clean and simple design approach',
      variant: 'minimalist',
      config: {
        '--pi-primary-color': '#6b7280',
        '--pi-secondary-color': '#9ca3af',
        '--pi-text-color': '#374151',
        '--pi-background-color': '#ffffff',
        '--pi-border-color': '#d1d5db',
        '--pi-hover-color': '#4b5563',
        '--pi-font-family': this.getFontFamilyWithFallbacks(),
        '--pi-border-radius': '6px',
        '--pi-box-shadow': '0 1px 3px rgba(0,0,0,0.1)'
      }
    };
  }

  buildVariantOverrides(variant, tokens) {
    if (!variant) return '';
    const colors = tokens.colors || {};
    const primary = colors.primary || '#2563eb';
    const primaryLight = this.lightenColor(primary, 25);
    const primaryDark = this.darkenColor(primary, 20);
    const text = colors.text || '#1f2937';
    const bg = colors.bg || '#ffffff';
    const border = colors.answerBorder || this.lightenColor(primary, 35);

    switch (variant) {
      case 'high-contrast':
        return `
#_pi_surveyWidgetContainer {
  background-color: ${bg} !important;
  color: ${text} !important;
}
#_pi_surveyWidgetContainer ._pi_question,
#_pi_surveyWidgetContainer ._pi_header {
  font-weight: 700 !important;
  letter-spacing: 0.01em !important;
}
#_pi_surveyWidgetContainer ul._pi_answers_container li {
  border-width: 3px !important;
  border-color: ${primary} !important;
  background-color: ${bg} !important;
}
#_pi_surveyWidgetContainer a._pi_startButton,
#_pi_surveyWidgetContainer ._pi_slider_question_submit_button {
  background: ${primary} !important;
  border-color: ${primary} !important;
  color: ${colors.onPrimary || '#ffffff'} !important;
  text-transform: uppercase !important;
  border-width: 3px !important;
}
#_pi_surveyWidgetContainer a._pi_startButton:hover,
#_pi_surveyWidgetContainer ._pi_slider_question_submit_button:hover {
  background: ${primaryDark} !important;
  border-color: ${primaryDark} !important;
}
`;
      case 'modern':
        return `
#_pi_surveyWidget,
#_pi_surveyWidget[survey-widget-type="fullscreensurvey"],
#_pi_surveyWidget[survey-widget-type="inlinesurvey"] {
  background-image: linear-gradient(135deg, ${primary} 0%, ${primaryLight} 100%) !important;
  border-radius: 24px !important;
  box-shadow: 0 20px 40px rgba(0,0,0,0.2) !important;
}
#_pi_surveyWidgetContainer ul._pi_answers_container[data-question-type="single_choice_question"] li a {
  border-radius: 18px !important;
  background: rgba(255,255,255,0.85) !important;
  box-shadow: 0 10px 20px rgba(0,0,0,0.08) !important;
}
#_pi_surveyWidgetContainer ._pi_slider .noUi-connect {
  background: ${primaryDark} !important;
}
#_pi_surveyWidgetContainer ul._pi_answers_container li:hover a {
  transform: translateY(-2px);
  box-shadow: 0 16px 30px rgba(0,0,0,0.12) !important;
}
#_pi_surveyWidgetContainer a._pi_startButton {
  border-radius: 999px !important;
  padding: 0.85rem 2.5rem !important;
}
`;
      case 'minimalist':
        return `
#_pi_surveyWidget,
#_pi_surveyWidgetContainer ._pi_widgetContentContainer {
  background: ${bg} !important;
  box-shadow: none !important;
  border-radius: 6px !important;
}
#_pi_surveyWidgetContainer ul._pi_answers_container li {
  border: 1px solid ${this.ensureBorderVisibility(border, bg)} !important;
  background: transparent !important;
  box-shadow: none !important;
}
#_pi_surveyWidgetContainer a._pi_startButton {
  background: transparent !important;
  color: ${primary} !important;
  border: 1px solid ${this.ensureBorderVisibility(primary, bg)} !important;
  text-transform: none !important;
}
#_pi_surveyWidgetContainer a._pi_startButton:hover {
  background: ${primary} !important;
  color: ${colors.onPrimary || '#ffffff'} !important;
}
#_pi_surveyWidgetContainer select._pi_select,
#_pi_surveyWidgetContainer ._pi_free_text_question_field_container textarea,
#_pi_surveyWidgetContainer ._pi_free_text_question_field_container input[type="text"] {
  border: none !important;
  border-bottom: 1px solid ${this.ensureBorderVisibility(border, bg)} !important;
  border-radius: 0 !important;
  box-shadow: none !important;
}
`;
      case 'brand':
      default:
        return `
#_pi_surveyWidget[survey-widget-type="topbarsurvey"],
#_pi_surveyWidget[survey-widget-type="bottombarsurvey"] {
  background-color: ${primary} !important;
  color: ${colors.onPrimary || '#ffffff'} !important;
  box-shadow: 0 12px 24px rgba(0,0,0,0.18) !important;
}
#_pi_surveyWidgetContainer ._pi_branding {
  color: ${primaryDark} !important;
}
#_pi_surveyWidgetContainer ._pi_branding:hover {
  color: ${primary} !important;
}
`;
    }
  }

  buildThemeTokens(config = {}, overrides = {}) {
    const variantId = overrides.variant || 'brand';
    const rawPrimary = config['--pi-primary-color'] || '#0067b8';
    const background = this.normalizeColorValue(config['--pi-background-color'] || '#ffffff', '#ffffff');
    const textBase = this.normalizeColorValue(config['--pi-text-color'] || '#1f2937', '#1f2937');
    const primary = this.normalizeColorValue(rawPrimary, '#0067b8');
    const hover = this.normalizeColorValue(config['--pi-hover-color'] || this.darkenColor(primary, 15), this.darkenColor(primary, 15));
    const primaryActive = this.normalizeColorValue(this.darkenColor(primary, 25), this.darkenColor(primary, 25));
    const border = this.normalizeColorValue(config['--pi-border-color'] || this.lightenColor(primary, 40), this.lightenColor(primary, 40));
    const secondary = this.normalizeColorValue(config['--pi-secondary-color'] || this.lightenColor(primary, 30), this.lightenColor(primary, 30));
    const radius = config['--pi-border-radius'] || '8px';
    const shadow = config['--pi-box-shadow'] || '0 4px 12px rgba(0,0,0,0.15)';
    const fontFamily = this.getFontFamilyWithFallbacks(config['--pi-font-family']);
    const onPrimary = this.getAccessibleOnPrimary(primary, '#ffffff');
    const legibleText = this.ensureReadableText(textBase, background);
    const buttonWeight = variantId === 'high-contrast' ? '700' : '600';
    const mobileGapRow = variantId === 'modern' ? '12px' : '8px';
    const mobileGapCol = variantId === 'modern' ? '18px' : '16px';
    const radioStyle = variantId === 'modern' ? 'tile' : 'dot';
    const inputStyle = variantId === 'minimalist' ? 'underline' : 'box';

    return {
      name: overrides.name || config.name,
      typography: {
        fontFamily,
        closeButtonFamily: fontFamily,
        closeButtonSize: '32px',
        sizes: { question: '28px', answer: '16px', body: '16px', caption: '14px' },
        weights: { question: '500', answer: '400', body: '400', caption: '400' }
      },
      colors: {
        text: legibleText,
        bg: background,
        primary,
        primaryHover: hover,
        primaryActive,
        onPrimary,
        answerBorder: this.ensureBorderVisibility(border, background),
        radioBorder: this.ensureBorderVisibility(border, background),
        inputBorder: this.ensureBorderVisibility(border, background),
        inputFocus: hover,
        muted: this.ensureReadableAccent(secondary, background),
        darkColor: null
      },
      radii: {
        sm: this.scaleRadius(radius, 0.5),
        md: radius
      },
      shadows: { bar: shadow },
      layout: { gapRow: '8px', gapCol: '16px' },
      buttons: { paddingDesktop: '12px 30px', paddingMobile: '10px 20px', fontWeight: buttonWeight },
      inputs: { style: inputStyle, height: '48px', radius },
      answers: {
        radioStyle,
        radioOuter: '16px',
        radioInner: '8px',
        radioBorderWidth: '2px',
        tileSize: '64px',
        textAlignWhenRadioOn: 'left',
        textAlignWhenRadioOff: 'center'
      },
      widgets: {},
      modes: { mobile: { gapRow: mobileGapRow, gapCol: mobileGapCol } },
      variant: variantId
    };
  }

  normalizeColorValue(value, fallback) {
    if (!value || typeof value !== 'string') {
      return fallback || null;
    }
    const parsed = this.parseColor(value);
    if (!parsed) {
      if (fallback) return fallback;
      return null;
    }
    return this.rgbToHex(parsed);
  }

  ensureReadableText(textColor, backgroundColor) {
    const textRgb = this.parseColor(textColor);
    const bgRgb = this.parseColor(backgroundColor);
    if (!textRgb || !bgRgb) return textColor;
    const contrast = this.contrastRatio(textRgb, bgRgb);
    if (contrast >= 4.5) return textColor;
    const whiteContrast = this.contrastRatio(this.parseColor('#ffffff'), bgRgb);
    const darkContrast = this.contrastRatio(this.parseColor('#111111'), bgRgb);
    return whiteContrast >= darkContrast ? '#ffffff' : '#111111';
  }

  ensureBorderVisibility(borderColor, backgroundColor) {
    const borderRgb = this.parseColor(borderColor);
    const bgRgb = this.parseColor(backgroundColor);
    if (!borderRgb || !bgRgb) return borderColor;
    const contrast = this.contrastRatio(borderRgb, bgRgb);
    if (contrast >= 2.5) return borderColor;
    return contrast < 1.5 ? this.darkenColor(backgroundColor, 30) : this.lightenColor(backgroundColor, 30);
  }

  ensureReadableAccent(accentColor, backgroundColor) {
    const accentRgb = this.parseColor(accentColor);
    const bgRgb = this.parseColor(backgroundColor);
    if (!accentRgb || !bgRgb) return accentColor;
    const contrast = this.contrastRatio(accentRgb, bgRgb);
    if (contrast >= 3) return accentColor;
    return this.darkenColor(backgroundColor, 40);
  }

  saveThemes(themes, clientName = 'default') {
    console.log(`💾 Saving themes for client: ${clientName}`);

    const clientDir = `./output/client-themes/${clientName}`;
    if (!fs.existsSync(clientDir)) {
      fs.mkdirSync(clientDir, { recursive: true });
    }

    themes.forEach(theme => {
      const tokens = theme.tokens || this.buildThemeTokens(theme.config, { name: theme.name, variant: theme.variant });
      const { css, warnings, errors } = compileTheme(tokens);
      if (errors.length) {
        throw new Error(`Failed to compile theme "${theme.name}": ${errors.join('; ')}`);
      }
      warnings.forEach(msg => console.warn(`   ⚠️  ${theme.name}: ${msg}`));
      const filename = theme.name.toLowerCase().replace(/\s+/g, '-') + '.css';
      const filepath = path.join(clientDir, filename);

      const overrides = theme.overrides || this.buildVariantOverrides(theme.variant, tokens);
      const finalCss =
        overrides && overrides.trim().length
          ? `${css}\n\n/* Theme Variant Overrides (${theme.variant}) */\n${overrides}`
          : css;

      fs.writeFileSync(filepath, finalCss);
      console.log(`   ✅ Generated: ${filepath}`);

      theme.tokens = tokens;
      theme.overrides = overrides;
    });

    fs.writeFileSync(path.join(clientDir, 'themes.json'), JSON.stringify(themes, null, 2));

    this.updateClientIndex(clientName, themes);

    console.log(`✅ All themes saved for ${clientName}`);
  }

  updateClientIndex(clientName, themes) {
    const indexFile = './output/client-themes/index.json';
    let clients = {};

    if (fs.existsSync(indexFile)) {
      clients = JSON.parse(fs.readFileSync(indexFile, 'utf8'));
    }

    clients[clientName] = {
      name: clientName,
      themes: themes.map(theme => ({
        id: theme.name.toLowerCase().replace(/\s+/g, '-'),
        name: theme.name,
        description: theme.description,
        file: `${theme.name.toLowerCase().replace(/\s+/g, '-')}.css`
      })),
      lastUpdated: new Date().toISOString()
    };

    fs.writeFileSync(indexFile, JSON.stringify(clients, null, 2));
    console.log('   📝 Updated client index');
  }

  lightenColor(color, percent) {
    const rgb = this.parseColor(color);
    if (!rgb) {
      return color;
    }
    const factor = Math.max(0, Math.min(100, percent)) / 100;
    const lightenChannel = channel => this.clampChannel(channel + (255 - channel) * factor);
    const adjusted = {
      r: lightenChannel(rgb.r),
      g: lightenChannel(rgb.g),
      b: lightenChannel(rgb.b)
    };
    return this.rgbToHex(adjusted);
  }

  darkenColor(color, percent) {
    const rgb = this.parseColor(color);
    if (!rgb) {
      return color;
    }
    const factor = Math.max(0, Math.min(100, percent)) / 100;
    const darkenChannel = channel => this.clampChannel(channel * (1 - factor));
    const adjusted = {
      r: darkenChannel(rgb.r),
      g: darkenChannel(rgb.g),
      b: darkenChannel(rgb.b)
    };
    return this.rgbToHex(adjusted);
  }

  modernizeColor(color) {
    const rgb = this.parseColor(color);
    if (!rgb) {
      return color;
    }
    const { r, g, b } = rgb;
    if (r > 200 && g < 100 && b < 100) {
      return '#ef4444';
    }
    if (r < 100 && g > 200 && b < 100) {
      return '#10b981';
    }
    if (r < 100 && g < 100 && b > 200) {
      return '#3b82f6';
    }
    if (r > 200 && g > 200 && b < 100) {
      return '#f59e0b';
    }
    if (r > 200 && g < 100 && b > 200) {
      return '#8b5cf6';
    }
    return '#6366f1';
  }

  getAccessibleOnPrimary(primary, fallbackText) {
    const primaryRgb = this.parseColor(primary);
    if (!primaryRgb) {
      return fallbackText || '#ffffff';
    }
    const fallbackRgb = this.parseColor(fallbackText);
    if (fallbackRgb && this.contrastRatio(primaryRgb, fallbackRgb) >= 4.5) {
      return fallbackText;
    }
    const whiteContrast = this.contrastRatio(primaryRgb, this.parseColor('#ffffff'));
    const darkContrast = this.contrastRatio(primaryRgb, this.parseColor('#111827'));
    return whiteContrast >= darkContrast ? '#ffffff' : '#111827';
  }

  scaleRadius(value, factor) {
    if (!value) return '4px';
    const match = String(value).trim().match(/^([\d.]+)([a-z%]*)$/i);
    if (!match) return value;
    const amount = parseFloat(match[1]);
    const unit = match[2] || 'px';
    const scaled = Math.max(0, amount * factor);
    const rounded = Math.round(scaled * 100) / 100;
    return `${rounded}${unit}`;
  }

  parseColor(color) {
    return parseThemeColor(color);
  }

  contrastRatio(a, b) {
    if (!a || !b) return 0;
    return computeContrast(a, b);
  }

  clampChannel(value) {
    return Math.round(Math.max(0, Math.min(255, value)));
  }

  rgbToHex({ r, g, b }) {
    const toHex = channel => this.clampChannel(channel).toString(16).padStart(2, '0');
    return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
  }
}

module.exports = SimpleThemeGenerator;

async function main() {
  const analysisFile = process.argv[2];
  const clientName = process.argv[3] || 'default';

  if (!analysisFile) {
    console.log('Usage: node theme-generator.js <analysis-file> [client-name]');
    console.log('Example: node theme-generator.js ./output/site-analysis.json my-client');
    process.exit(1);
  }

  try {
    const analysis = JSON.parse(fs.readFileSync(analysisFile, 'utf8'));
    const generator = new SimpleThemeGenerator(analysis);
    const themes = generator.generateThemes();

    generator.saveThemes(themes, clientName);

    console.log('🎉 Themes generated successfully!');
    console.log(`📁 Check ./output/client-themes/${clientName}/ for your CSS files`);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch(console.error);
}
