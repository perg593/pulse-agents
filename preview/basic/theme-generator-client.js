import {
  compileTheme,
  parseColor as parseCssColor,
  relativeLuminance,
  contrastRatio as computeContrastRatio
} from './theme-css.js';
import { applyTokenDefaults } from '../theme-generator/tokens/schema.js';

const DEFAULT_ANALYSIS_COLORS = {
  backgrounds: ['#ffffff', '#f8f9fa', '#e9ecef'],
  textColors: ['#1f2937', '#111827', '#4b5563'],
  accentColors: ['#2563eb', '#1d4ed8', '#1e40af'],
  borderColors: ['#d1d5db', '#e5e7eb']
};

export async function generateThemesFromUrl(rawUrl) {
  const url = normalizeUrl(rawUrl);
  if (!url) {
    throw new Error('Please enter a valid URL.');
  }

  const response = await fetch(url, { mode: 'cors', credentials: 'omit' });
  const finalUrl = response.url || url;
  const analysis = await analyzeUrl(finalUrl, response);
  const generator = new SimpleThemeGenerator(analysis);
  const variants = generator.generateThemes();

  const timestamp = Date.now();
  return {
    url: finalUrl,
    analysis,
    themes: variants.map((theme, index) => {
      const { css, warnings, errors } = compileTheme(theme.tokens);
      if (errors.length) {
        throw new Error(`Failed to compile theme "${theme.name}": ${errors.join('; ')}`);
      }
      return {
        id: `generated-${timestamp}-${index}`,
        name: theme.name,
        description: theme.description,
        css,
        warnings,
        tokens: theme.tokens,
        variant: theme.variant || 'brand'
      };
    })
  };
}

function normalizeUrl(value) {
  const trimmed = (value || '').trim();
  if (!trimmed) return '';
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  return `https://${trimmed}`;
}

function shouldProxy(url) {
  if (!url) return false;
  if (!/^https?:\/\//i.test(url)) return false;
  const origin = (window.__PI_PROXY_ORIGIN__ || '').trim();
  if (!origin) return false;
  if (url.startsWith(origin)) return false;
  if (url.includes('/proxy?url=')) return false;
  return true;
}

function buildProxyUrl(url) {
  if (!url) return url;
  if (!shouldProxy(url)) return url;
  const origin = window.__PI_PROXY_ORIGIN__.replace(/\/$/, '');
  return `${origin}/proxy?url=${encodeURIComponent(url)}`;
}

async function analyzeUrl(url, initialResponse) {
  try {
    let response = initialResponse;
    if (!response) {
      const fetchUrl = buildProxyUrl(url);
      response = await fetch(fetchUrl, { mode: 'cors', credentials: 'omit' });
    }
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const finalUrl = response.url || url;
    const html = await response.text();
    return await buildAnalysisFromHtml(finalUrl, html);
  } catch (error) {
    return fallbackAnalysis(url, error);
  }
}

async function buildAnalysisFromHtml(url, html) {
  const parser = new DOMParser();
  const doc = parser.parseFromString(html, 'text/html');
  const styleColors = extractColorsFromStyles(doc);
  const textColors = extractColorsFromText(html);
  const allColors = uniqueNonEmpty([...styleColors, ...textColors]);
  const classified = classifyColors(allColors);
  const fontFamilies = extractFontFamilies(html, doc);
  const logoExtraction = await collectLogoColors(doc, url);

  return {
    url,
    colors: {
      backgrounds: fallbackList(classified.backgrounds, DEFAULT_ANALYSIS_COLORS.backgrounds),
      textColors: fallbackList(classified.text, DEFAULT_ANALYSIS_COLORS.textColors),
      accentColors: fallbackList(classified.accents, DEFAULT_ANALYSIS_COLORS.accentColors),
      borderColors: fallbackList(classified.borders, DEFAULT_ANALYSIS_COLORS.borderColors),
      primaryBackground: classified.backgrounds[0] || DEFAULT_ANALYSIS_COLORS.backgrounds[0],
      primaryText: classified.text[0] || DEFAULT_ANALYSIS_COLORS.textColors[0],
      rootVariables: extractRootVariables(html),
      logoColors: logoExtraction.colors
    },
    fonts: {
      families: fontFamilies.length ? fontFamilies : ['system-ui'],
      sizes: [],
      weights: []
    },
    timestamp: new Date().toISOString(),
    fallback: false,
    assets: {
      logoSources: logoExtraction.sources
    }
  };
}

function extractColorsFromStyles(doc) {
  const results = [];
  const elements = Array.from(doc.querySelectorAll('[style]'));
  elements.forEach((el) => {
    const style = el.getAttribute('style');
    if (!style) return;
    const matches = style.match(COLOR_REGEX) || [];
    matches.forEach((match) => results.push(normalizeColor(match)));
  });
  return results;
}

function extractColorsFromText(html) {
  const matches = html.match(COLOR_REGEX) || [];
  return matches.map(normalizeColor);
}

function normalizeColor(value) {
  return value.trim().replace(/;$/, '');
}

function classifyColors(colors) {
  const mapped = colors
    .map((value) => {
      const rgb = parseCssColor(value);
      if (!rgb) return null;
      const luminance = relativeLuminance(rgb);
      const hex = rgbToHex(rgb);
      return { value: hex, luminance };
    })
    .filter(Boolean);

  const unique = uniqueBy(mapped, (item) => item.value.toLowerCase());
  const sorted = unique.sort((a, b) => a.luminance - b.luminance);

  const dark = sorted.filter((item) => item.luminance <= 0.35).map((item) => item.value);
  const light = sorted.filter((item) => item.luminance >= 0.65).map((item) => item.value);
  const middle = sorted.filter((item) => item.luminance > 0.35 && item.luminance < 0.65).map((item) => item.value);

  return {
    text: dark.slice(0, 8),
    backgrounds: light.slice(0, 8),
    accents: middle.concat(light.slice(2)).slice(0, 12),
    borders: middle.slice(0, 8)
  };
}

function extractFontFamilies(html, doc) {
  const inlineFamilies = Array.from(doc.querySelectorAll('[style]'))
    .map((el) => el.getAttribute('style') || '')
    .flatMap((style) => {
      const matches = [];
      const regex = /font-family\s*:\s*([^;"']+)/gi;
      let match;
      while ((match = regex.exec(style))) {
        matches.push(cleanFontFamily(match[1]));
      }
      return matches;
    });

  const cssFamilies = [];
  const regex = /font-family\s*:\s*([^;\}]+)/gi;
  let match;
  while ((match = regex.exec(html))) {
    cssFamilies.push(cleanFontFamily(match[1]));
  }

  return uniqueNonEmpty([...inlineFamilies, ...cssFamilies]).slice(0, 6);
}

function cleanFontFamily(value) {
  const first = value.split(',')[0] || '';
  return first.trim().replace(/["']/g, '');
}

function extractRootVariables(html) {
  const results = {};
  const rootRegex = /:root\s*\{([^}]+)\}/gi;
  let match;
  while ((match = rootRegex.exec(html))) {
    const block = match[1] || '';
    const varRegex = /(--[a-z0-9-_]+)\s*:\s*([^;]+);/gi;
    let varMatch;
    while ((varMatch = varRegex.exec(block))) {
      const name = varMatch[1].trim();
      const value = (varMatch[2] || '').trim();
      if (name && value && !results[name]) {
        results[name] = value;
      }
    }
  }
  return results;
}

function fallbackAnalysis(url, error) {
  console.warn('Theme generator using fallback analysis:', error?.message || error);
  const colors = DEFAULT_ANALYSIS_COLORS;
  return {
    url,
    colors: {
      ...colors,
      primaryBackground: colors.backgrounds[0],
      primaryText: colors.textColors[0],
      rootVariables: {},
      logoColors: []
    },
    fonts: {
      families: ['system-ui', 'Arial', 'Helvetica Neue'],
      sizes: ['16px', '18px', '14px'],
      weights: ['400', '500', '600']
    },
    timestamp: new Date().toISOString(),
    fallback: true,
    assets: {
      logoSources: []
    }
  };
}

const COLOR_REGEX = /#(?:[0-9a-fA-F]{3,8})\b|rgba?\([^\)]+\)/g;
const LOGO_HINT_REGEX = /(logo|brand|badge|lockup|wordmark|identity|mark|favicon)/i;
const LOGO_COLOR_LIMIT = 6;
const LOGO_MAX_ASSETS = 4;
const TRANSPARENT_ALPHA_THRESHOLD = 200;

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

  generateThemes() {
    const baseThemes = [
      this.generateBrandFaithfulTheme(),
      this.generateHighContrastTheme(),
      this.generateModernTheme(),
      this.generateMinimalistTheme()
    ];

    return baseThemes.map((theme) => {
      const tokens = this.buildThemeTokens(theme.config, { name: theme.name, variant: theme.variant });
      return {
        ...theme,
        tokens
      };
    });
  }

  getFontFamilyWithFallbacks(fontName) {
    if (!fontName) {
      return 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';
    }
    if (fontName.includes(',') && fontName.toLowerCase().includes('sans-serif')) {
      return fontName;
    }
    const trimmed = fontName.replace(/['"]/g, '').trim();
    const fallbacks =
      'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';
    return `"${trimmed}", ${fallbacks}`;
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

  generateBrandFaithfulTheme() {
    const isAirSupra = (this.analysis.url || '').includes('airsupra');
    const fontFamily = this.getFontFamilyWithFallbacks(this.analysis.fonts.families[0]);
    const colors = this.analysis.colors || {};

    if (isAirSupra) {
      return {
        name: 'Brand Faithful',
        description: "Matches AirSupra's brand colors and fonts",
        variant: 'brand',
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
      description: "Matches the site's detected colors and fonts",
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

    if (rootCandidates.accent.length) accentColors.unshift(...rootCandidates.accent);
    if (rootCandidates.background.length) backgroundCandidates.unshift(...rootCandidates.background);
    if (rootCandidates.text.length) textCandidates.unshift(...rootCandidates.text);
    if (rootCandidates.border.length) borderCandidates.unshift(...rootCandidates.border);

    let primaryColor = accentColors[0] || '#007bff';
    let secondaryColor = accentColors[1] || '#6b7280';
    let textColor = textCandidates[0] || '#1f2937';
    let backgroundColor = backgroundCandidates[0] || '#ffffff';
    let borderColor = borderCandidates[0] || this.lightenColor(primaryColor, 40);
    let hoverColor = this.darkenColor(primaryColor, 15);

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
      description: 'Accessibility-first palette with high contrast',
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
    const fontFamily = this.getFontFamilyWithFallbacks(this.analysis.fonts.families[1] || this.analysis.fonts.families[0]);

    const modernPrimary = this.modernizeColor(brandPrimary);
    const modernSecondary = this.modernizeColor(brandSecondary);

    return {
      name: 'Modern',
      description: 'Contemporary gradient-inspired theme',
      variant: 'modern',
      config: {
        '--pi-primary-color': modernPrimary,
        '--pi-secondary-color': modernSecondary,
        '--pi-text-color': '#1f2937',
        '--pi-background-color': '#ffffff',
        '--pi-border-color': '#e5e7eb',
        '--pi-hover-color': this.darkenColor(modernPrimary, 10),
        '--pi-font-family': fontFamily,
        '--pi-border-radius': '16px',
        '--pi-box-shadow': '0 18px 40px rgba(0,0,0,0.18)'
      }
    };
  }

  generateMinimalistTheme() {
    return {
      name: 'Minimalist',
      description: 'Neutral palette with subtle accents',
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
        '--pi-box-shadow': '0 1px 3px rgba(0,0,0,0.08)'
      }
    };
  }

  buildThemeTokens(config = {}, overrides = {}) {
    const variantId = overrides.variant || 'brand';
    const tokens = applyTokenDefaults();

    const rawPrimary = config['--pi-primary-color'] || '#2563eb';
    const primary = this.normalizeColorValue(rawPrimary, '#2563eb');
    const background = this.normalizeColorValue(config['--pi-background-color'] || '#ffffff', '#ffffff');
    const textBase = this.normalizeColorValue(config['--pi-text-color'] || '#1f2937', '#1f2937');
    const hover = this.normalizeColorValue(
      config['--pi-hover-color'] || this.darkenColor(primary, 15),
      this.darkenColor(primary, 15)
    );
    const active = this.normalizeColorValue(this.darkenColor(primary, 25), this.darkenColor(primary, 25));
    const secondary = this.normalizeColorValue(
      config['--pi-secondary-color'] || this.lightenColor(primary, 30),
      this.lightenColor(primary, 30)
    );
    const border = this.normalizeColorValue(
      config['--pi-border-color'] || this.lightenColor(primary, 45),
      this.lightenColor(primary, 45)
    );
    const radius = config['--pi-border-radius'] || '14px';
    const shadow = config['--pi-box-shadow'] || '0 18px 40px rgba(15, 23, 42, 0.18)';
    const fontFamily = this.getFontFamilyWithFallbacks(config['--pi-font-family']);

    const legibleText = this.ensureReadableText(textBase, background);
    const onPrimary = this.getAccessibleOnPrimary(primary, '#ffffff');
    const answerBorder = this.ensureBorderVisibility(border, background);
    const muted = this.ensureReadableAccent(secondary, background);

    tokens.colors.primary = primary;
    tokens.colors.primaryHover = hover;
    tokens.colors.primaryActive = active;
    tokens.colors.secondary = secondary;
    tokens.colors.text = legibleText;
    tokens.colors.bg = background;
    tokens.colors.muted = muted;
    tokens.colors.answerBorder = answerBorder;
    tokens.colors.radioBorder = answerBorder;
    tokens.colors.inputBorder = answerBorder;
    tokens.colors.inputFocus = hover;
    tokens.colors.onPrimary = onPrimary;

    tokens.typography.fontFamily = fontFamily;
    tokens.typography.closeButtonFamily = fontFamily;
    tokens.typography.closeButtonSize = '32px';
    tokens.typography.sizes.question = '28px';
    tokens.typography.sizes.answer = '16px';
    tokens.typography.sizes.body = '16px';
    tokens.typography.sizes.caption = '14px';
    tokens.typography.weights.question = variantId === 'high-contrast' ? '700' : '600';
    tokens.typography.weights.answer = variantId === 'high-contrast' ? '600' : '500';
    tokens.typography.weights.body = '400';
    tokens.typography.weights.caption = '400';
    tokens.typography.lineHeights.question = '1.3';
    tokens.typography.lineHeights.answer = '1.4';
    tokens.typography.lineHeights.body = '1.5';

    tokens.layout.gapRow = '12px';
    tokens.layout.gapCol = '12px';

    tokens.shape.widgetRadius = radius;
    tokens.shape.controlRadius = this.scaleRadius(radius, 0.8);
    tokens.shape.buttonRadius = this.scaleRadius(radius, 0.6);

    tokens.shadows.widget = shadow;
    tokens.shadows.bar = '0px -1px 12px rgba(15, 23, 42, 0.2)';

    tokens.buttons.paddingDesktop = '12px 28px';
    tokens.buttons.paddingMobile = '12px 20px';
    tokens.buttons.fontWeight = variantId === 'high-contrast' ? '700' : '600';

    tokens.answers.radioStyle = variantId === 'modern' ? 'tile' : 'dot';
    tokens.answers.radioOuter = '18px';
    tokens.answers.radioInner = '10px';
    tokens.answers.radioBorderWidth = '2px';
    tokens.answers.tileSize = '60px';
    tokens.answers.textAlignWhenRadioOn = variantId === 'modern' ? 'left' : 'center';
    tokens.answers.textAlignWhenRadioOff = 'center';

    tokens.inputs.style = variantId === 'minimalist' ? 'underline' : 'box';
    tokens.inputs.height = '48px';
    tokens.inputs.radius = this.scaleRadius(radius, 0.75);

    tokens.focus.color = this.lightenColor(primary, 35);
    tokens.focus.width = '2px';
    tokens.focus.offset = '2px';
    tokens.focus.style = 'solid';
    tokens.focus.radius = tokens.shape.controlRadius;

    tokens.states.button.default.fill = primary;
    tokens.states.button.default.border = `1px solid ${primary}`;
    tokens.states.button.default.color = onPrimary;
    tokens.states.button.hover.fill = hover;
    tokens.states.button.hover.border = `1px solid ${hover}`;
    tokens.states.button.hover.color = onPrimary;
    tokens.states.button.active.fill = active;
    tokens.states.button.active.border = `1px solid ${active}`;
    tokens.states.button.active.color = onPrimary;
    tokens.states.button.focus.fill = hover;
    tokens.states.button.focus.border = '2px solid #ffffff';
    tokens.states.button.focus.color = onPrimary;
    tokens.states.button.selected.fill = '#ffffff';
    tokens.states.button.selected.border = `2px solid ${primary}`;
    tokens.states.button.selected.color = primary;

    if (variantId === 'modern') {
      tokens.shape.widgetRadius = '24px';
      tokens.shape.buttonRadius = '18px';
      tokens.layout.gapRow = '14px';
      tokens.buttons.fontWeight = '600';
      tokens.shadows.widget = '0 30px 60px rgba(15, 23, 42, 0.25)';
    }

    if (variantId === 'minimalist') {
      tokens.shadows.widget = 'none';
      tokens.shape.widgetRadius = '8px';
      tokens.buttons.fontWeight = '500';
    }

    return tokens;
  }

  normalizeColorValue(value, fallback) {
    if (!value || typeof value !== 'string') {
      return fallback || null;
    }
    const parsed = this.parseColor(value);
    if (!parsed) {
      return fallback || null;
    }
    return rgbToHex(parsed);
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

  lightenColor(color, percent) {
    const rgb = this.parseColor(color);
    if (!rgb) return color;
    const factor = Math.max(0, Math.min(100, percent)) / 100;
    const lightenChannel = (channel) => clampChannel(channel + (255 - channel) * factor);
    const adjusted = {
      r: lightenChannel(rgb.r),
      g: lightenChannel(rgb.g),
      b: lightenChannel(rgb.b)
    };
    return rgbToHex(adjusted);
  }

  darkenColor(color, percent) {
    const rgb = this.parseColor(color);
    if (!rgb) return color;
    const factor = Math.max(0, Math.min(100, percent)) / 100;
    const darkenChannel = (channel) => clampChannel(channel * (1 - factor));
    const adjusted = {
      r: darkenChannel(rgb.r),
      g: darkenChannel(rgb.g),
      b: darkenChannel(rgb.b)
    };
    return rgbToHex(adjusted);
  }

  modernizeColor(color) {
    const rgb = this.parseColor(color);
    if (!rgb) return color;
    const { r, g, b } = rgb;
    if (r > 200 && g < 100 && b < 100) return '#ef4444';
    if (r < 100 && g > 200 && b < 100) return '#10b981';
    if (r < 100 && g < 100 && b > 200) return '#3b82f6';
    if (r > 200 && g > 200 && b < 100) return '#f59e0b';
    if (r > 200 && g < 100 && b > 200) return '#8b5cf6';
    return '#6366f1';
  }

  getAccessibleOnPrimary(primary, fallbackText) {
    const primaryRgb = this.parseColor(primary);
    if (!primaryRgb) return fallbackText || '#ffffff';
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
    return `${Math.round(scaled * 100) / 100}${unit}`;
  }

  parseColor(color) {
    return parseCssColor(color);
  }

  contrastRatio(a, b) {
    if (!a || !b) return 0;
    return computeContrastRatio(a, b);
  }
}

function fallbackList(candidate, fallback) {
  return candidate.length ? candidate : fallback;
}

function uniqueNonEmpty(array) {
  const seen = new Set();
  const results = [];
  array.forEach((item) => {
    const value = (item || '').trim();
    if (!value) return;
    const key = value.toLowerCase();
    if (!seen.has(key)) {
      seen.add(key);
      results.push(value);
    }
  });
  return results;
}

function uniqueBy(array, selector) {
  const seen = new Set();
  const results = [];
  array.forEach((item) => {
    const key = selector(item);
    if (!seen.has(key)) {
      seen.add(key);
      results.push(item);
    }
  });
  return results;
}

function rgbToHex({ r, g, b }) {
  const toHex = (channel) => clampChannel(channel).toString(16).padStart(2, '0');
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

function clampChannel(value) {
  return Math.round(Math.max(0, Math.min(255, value)));
}

async function collectLogoColors(doc, baseUrl) {
  try {
    const inlineSvgs = extractInlineSvgMarkup(doc);
    const imageSources = gatherLogoImageSources(doc, baseUrl);
    const colorScores = new Map();
    const processedSources = [];

    inlineSvgs.forEach((svgMarkup) => {
      const colors = extractColorsFromSvgMarkup(svgMarkup);
      colors.forEach((color) => addColorScore(colorScores, color, 5));
    });

    for (const src of imageSources.slice(0, LOGO_MAX_ASSETS)) {
      if (src.startsWith('data:image/svg')) {
        const svgText = decodeDataUri(src);
        const colors = extractColorsFromSvgMarkup(svgText);
        colors.forEach((color) => addColorScore(colorScores, color, 4));
        continue;
      }

      try {
        const assetUrl = buildProxyUrl(src);
        const response = await fetch(assetUrl, { mode: 'cors', credentials: 'omit' });
        if (!response.ok) continue;
        const contentType = (response.headers.get('content-type') || '').toLowerCase();
        if (contentType.includes('svg') || src.toLowerCase().endsWith('.svg')) {
          const svgText = await response.text();
          const colors = extractColorsFromSvgMarkup(svgText);
          colors.forEach((color) => addColorScore(colorScores, color, 4));
        } else {
          const blob = await response.blob();
          const rasterColors = await sampleRasterColorsFromBlob(blob);
          rasterColors.forEach(([color, score]) => addColorScore(colorScores, color, score));
        }
        processedSources.push(src);
      } catch (error) {
        console.warn('Logo color fetch failed:', error);
      }
    }

    let sortedColors = Array.from(colorScores.entries())
      .sort((a, b) => b[1] - a[1])
      .map(([color]) => color)
      .filter((color) => !isVeryLightHex(color))
      .slice(0, LOGO_COLOR_LIMIT);

    if (!sortedColors.length && colorScores.size) {
      sortedColors = Array.from(colorScores.entries())
        .sort((a, b) => b[1] - a[1])
        .map(([color]) => color)
        .slice(0, LOGO_COLOR_LIMIT);
    }

    return {
      colors: sortedColors,
      sources: processedSources
    };
  } catch (error) {
    console.warn('Logo color extraction error:', error);
    return { colors: [], sources: [] };
  }
}

function gatherLogoImageSources(doc, baseUrl) {
  const primary = [];
  const secondary = [];
  const seen = new Set();

  const push = (value, isPrimary = false) => {
    if (!value) return;
    let absolute = value.trim();
    if (!absolute) return;
    if (!/^data:/i.test(absolute)) {
      try {
        absolute = new URL(absolute, baseUrl).href;
      } catch (error) {
        return;
      }
    }
    if (seen.has(absolute)) return;
    seen.add(absolute);
    if (isPrimary) {
      primary.push(absolute);
    } else {
      secondary.push(absolute);
    }
  };

  const imgElements = Array.from(doc.querySelectorAll('img'));
  imgElements.forEach((img) => {
    const src = img.getAttribute('src') || img.getAttribute('data-src') || '';
    const srcset = img.getAttribute('srcset') || '';
    const descriptor = [
      src,
      srcset.split(',')[0] || '',
      img.getAttribute('alt') || '',
      img.getAttribute('class') || '',
      img.getAttribute('id') || '',
      img.getAttribute('data-testid') || ''
    ].join(' ').toLowerCase();
    const isPrimary = LOGO_HINT_REGEX.test(descriptor);
    if (src) push(src, isPrimary);
    if (srcset) {
      const firstSrc = srcset.split(',')[0].trim().split(' ')[0];
      if (firstSrc) push(firstSrc, isPrimary);
    }
  });

  const pictureSources = Array.from(doc.querySelectorAll('picture source[srcset]'));
  pictureSources.forEach((source) => {
    const srcset = source.getAttribute('srcset') || '';
    if (!srcset) return;
    const firstSrc = srcset.split(',')[0].trim().split(' ')[0];
    const descriptor = [
      firstSrc,
      source.getAttribute('media') || '',
      source.getAttribute('type') || ''
    ].join(' ').toLowerCase();
    const isPrimary = LOGO_HINT_REGEX.test(descriptor);
    push(firstSrc, isPrimary);
  });

  const styledElements = Array.from(doc.querySelectorAll('[style*="background"], [style*="mask"]'));
  styledElements.forEach((el) => {
    const style = el.getAttribute('style') || '';
    const descriptor = [
      style,
      el.getAttribute('class') || '',
      el.getAttribute('id') || ''
    ].join(' ').toLowerCase();
    const isPrimary = LOGO_HINT_REGEX.test(descriptor);
    const urlRegex = /url\(("|')?([^"')]+)\1\)/gi;
    let match;
    while ((match = urlRegex.exec(style))) {
      push(match[2], isPrimary);
    }
  });

  const iconLinks = Array.from(doc.querySelectorAll('link[rel~="icon"], link[rel="apple-touch-icon"], link[rel="apple-touch-icon-precomposed"]'));
  iconLinks.forEach((link) => {
    push(link.getAttribute('href'), false);
  });

  const metaImages = Array.from(doc.querySelectorAll('meta[property="og:image"], meta[name="og:image"], meta[property="twitter:image"], meta[name="twitter:image"]'));
  metaImages.forEach((meta) => {
    push(meta.getAttribute('content'), false);
  });

  return primary.concat(secondary);
}

function extractInlineSvgMarkup(doc) {
  const svgElements = Array.from(doc.querySelectorAll('svg'));
  if (!svgElements.length) return [];
  const matches = svgElements.filter((svg) => isLikelyLogoElement(svg)).map((svg) => svg.outerHTML);
  if (matches.length) {
    return matches.slice(0, LOGO_MAX_ASSETS);
  }
  return [svgElements[0].outerHTML];
}

function isLikelyLogoElement(el) {
  if (!el || typeof el.getAttribute !== 'function') return false;
  const attributes = [
    el.getAttribute('id'),
    el.getAttribute('class'),
    el.getAttribute('alt'),
    el.getAttribute('aria-label'),
    el.getAttribute('role'),
    el.getAttribute('data-testid')
  ].filter(Boolean).join(' ').toLowerCase();
  if (LOGO_HINT_REGEX.test(attributes)) return true;
  let parent = el.parentNode;
  let depth = 0;
  while (parent && depth < 3) {
    if (parent.getAttribute) {
      const parentAttributes = [
        parent.getAttribute('id'),
        parent.getAttribute('class')
      ].filter(Boolean).join(' ').toLowerCase();
      if (LOGO_HINT_REGEX.test(parentAttributes)) return true;
    }
    parent = parent.parentNode;
    depth += 1;
  }
  return false;
}

function extractColorsFromSvgMarkup(svgText = '') {
  const colors = new Set();
  if (!svgText) return [];
  const attributeRegex = /(fill|stroke|stop-color)\s*=\s*"([^"]+)"/gi;
  let match;
  while ((match = attributeRegex.exec(svgText))) {
    const normalized = normalizeCssColorValue(match[2]);
    if (normalized) colors.add(normalized);
  }

  const styleAttrRegex = /style\s*=\s*"([^"]+)"/gi;
  let styleMatch;
  while ((styleMatch = styleAttrRegex.exec(svgText))) {
    const declarations = styleMatch[1].split(';');
    declarations.forEach((decl) => {
      const [prop, value] = decl.split(':');
      if (!value) return;
      if (/fill|stroke/i.test(prop)) {
        const normalized = normalizeCssColorValue(value);
        if (normalized) colors.add(normalized);
      }
    });
  }

  return Array.from(colors);
}

function normalizeCssColorValue(value) {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed === 'none') return null;
  if (/^url\(/i.test(trimmed) || /^var\(/i.test(trimmed) || /^currentColor$/i.test(trimmed)) return null;
  if (/^#[0-9a-f]{3}$/i.test(trimmed)) {
    return `#${trimmed[1]}${trimmed[1]}${trimmed[2]}${trimmed[2]}${trimmed[3]}${trimmed[3]}`.toLowerCase();
  }
  if (/^#[0-9a-f]{6}$/i.test(trimmed)) {
    return trimmed.toLowerCase();
  }
  const parsed = parseCssColor(trimmed);
  if (!parsed) return null;
  return rgbToHex(parsed);
}

async function sampleRasterColorsFromBlob(blob) {
  if (!blob) return [];
  const objectUrl = URL.createObjectURL(blob);
  try {
    const img = await loadImageFromBlob(objectUrl);
    const maxSize = 128;
    const maxDimension = Math.max(img.width || 1, img.height || 1);
    const scale = maxDimension > maxSize ? maxSize / maxDimension : 1;
    const width = Math.max(1, Math.round((img.width || maxSize) * scale));
    const height = Math.max(1, Math.round((img.height || maxSize) * scale));
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext('2d');
    if (!context) return [];
    context.drawImage(img, 0, 0, width, height);
    const imageData = context.getImageData(0, 0, width, height);
    const data = imageData.data;
    const colorCounts = new Map();
    const pixelCount = width * height;
    const step = Math.max(1, Math.floor(pixelCount / 5000));

    for (let index = 0; index < data.length; index += 4 * step) {
      const alpha = data[index + 3];
      if (alpha < TRANSPARENT_ALPHA_THRESHOLD) continue;
      const r = data[index];
      const g = data[index + 1];
      const b = data[index + 2];
      if (isVeryLightRGB(r, g, b)) continue;
      const hex = rgbToHex({ r, g, b });
      colorCounts.set(hex, (colorCounts.get(hex) || 0) + 1);
    }

    return Array.from(colorCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, LOGO_COLOR_LIMIT);
  } catch (error) {
    console.warn('Raster logo color sampling failed:', error);
    return [];
  } finally {
    URL.revokeObjectURL(objectUrl);
  }
}

function loadImageFromBlob(objectUrl) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = objectUrl;
  });
}

function decodeDataUri(dataUri) {
  if (!dataUri || !dataUri.startsWith('data:')) return '';
  const base64Match = dataUri.match(/^data:[^;]+;base64,(.+)$/);
  if (base64Match) {
    try {
      return atob(base64Match[1]);
    } catch (error) {
      console.warn('Failed to decode base64 data URI:', error);
      return '';
    }
  }
  const parts = dataUri.split(',', 2);
  if (parts.length === 2) {
    try {
      return decodeURIComponent(parts[1]);
    } catch (error) {
      return parts[1];
    }
  }
  return '';
}

function addColorScore(map, color, amount = 1) {
  if (!color) return;
  map.set(color, (map.get(color) || 0) + amount);
}

function isVeryLightHex(hex) {
  const rgb = parseCssColor(hex);
  if (!rgb) return false;
  return isVeryLightRGB(rgb.r, rgb.g, rgb.b);
}

function isVeryLightRGB(r, g, b) {
  return r > 245 && g > 245 && b > 245;
}
