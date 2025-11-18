import type { ExtractionData } from './colorExtraction';
import { 
  rgbToHex, 
  getMostCommonColor, 
  getHighSaturationColors, 
  getLightNeutrals,
  getDarkColors,
  isNearGrayscale,
  getBrightness,
  getContrastRatio,
  getSaturation,
  aggregateColors
} from './colorExtraction';

/**
 * Builds a final palette from extraction data
 * Phase 3.9: Implements brand color priority model with stability thresholds
 */
export function buildPaletteFromSamples(data: ExtractionData): {
  background: string;
  surface?: string;
  textPrimary: string;
  textSecondary?: string;
  brandPrimary?: string;
  brandSecondary?: string;
  accent?: string;
  logo?: string;
} {
  // Collect all color samples
  const allSamples = [
    ...data.buttonColors,
    ...data.linkColors,
    ...data.backgroundCandidates,
    ...data.surfaceCandidates
  ];
  
  // Extract CSS variable colors
  const cssVarColors: string[] = [];
  const cssVarMap: Record<string, string> = {};
  for (const [key, value] of Object.entries(data.cssVariables)) {
    if (value && value.startsWith('#')) {
      cssVarColors.push(value);
      cssVarMap[key.toLowerCase()] = value;
    } else if (value && value.startsWith('rgb')) {
      const hex = rgbToHex(value);
      cssVarColors.push(hex);
      cssVarMap[key.toLowerCase()] = hex;
    }
  }
  
  // 1. Background - prefer CSS variables, then most common light neutral
  let background = '#ffffff';
  if (cssVarColors.length > 0) {
    const lightCss = cssVarColors.filter(c => getBrightness(c) > 0.85);
    if (lightCss.length > 0) {
      background = lightCss[0];
    }
  }
  
  if (background === '#ffffff') {
    const lightNeutrals = getLightNeutrals(data.backgroundCandidates);
    if (lightNeutrals.length > 0) {
      background = lightNeutrals[0].color;
    } else {
      const mostCommonBg = getMostCommonColor(data.backgroundCandidates);
      if (mostCommonBg && getBrightness(mostCommonBg) > 0.7) {
        background = mostCommonBg;
      }
    }
  }
  
  // 2. Surface - secondary light neutral
  let surface: string | undefined;
  const lightNeutrals = getLightNeutrals(data.surfaceCandidates);
  if (lightNeutrals.length > 0) {
    surface = lightNeutrals[0].color;
  } else {
    const surfaceCandidates = data.surfaceCandidates
      .filter(s => getBrightness(s.color) > 0.7 && s.color !== background)
      .sort((a, b) => b.frequency - a.frequency);
    if (surfaceCandidates.length > 0) {
      surface = surfaceCandidates[0].color;
    }
  }
  
  // Generate surface if not found
  if (!surface) {
    const rgb = hexToRgb(background);
    if (rgb) {
      const r = Math.min(255, rgb.r + 5);
      const g = Math.min(255, rgb.g + 5);
      const b = Math.min(255, rgb.b + 5);
      surface = `#${((r << 16) | (g << 8) | b).toString(16).padStart(6, '0')}`;
    }
  }
  
  // 3. Brand Primary - Priority Model (Phase 3.9)
  let brandPrimary: string | undefined;
  
  // Priority 1: CSS variable colors (--brand-primary, --primary, --color-primary)
  const brandCssVarKeys = [
    '--brand-primary',
    '--primary',
    '--color-primary',
    '--brand-primary-color',
    '--theme-primary'
  ];
  
  for (const key of brandCssVarKeys) {
    const value = cssVarMap[key];
    if (value) {
      const sat = getSaturation(value);
      if (sat > 0.2 && !isNearGrayscale(value)) {
        brandPrimary = value;
        break;
      }
    }
  }
  
  // Priority 2: Logo dominant color
  if (!brandPrimary && data.logoHint && !isNearGrayscale(data.logoHint)) {
    const sat = getSaturation(data.logoHint);
    if (sat > 0.15) {
      brandPrimary = data.logoHint;
    }
  }
  
  // Priority 3: CTA button background colors (high frequency, high saturation)
  if (!brandPrimary) {
    const ctaBgColors = data.buttonColors
      .filter(s => {
        const sat = getSaturation(s.color);
        return sat > 0.3 && s.frequency >= 1.5; // CTA buttons have 1.5x weight
      })
      .sort((a, b) => {
        // Sort by frequency first, then saturation
        if (Math.abs(a.frequency - b.frequency) > 0.1) {
          return b.frequency - a.frequency;
        }
        return getSaturation(b.color) - getSaturation(a.color);
      });
    
    if (ctaBgColors.length > 0) {
      brandPrimary = ctaBgColors[0].color;
    }
  }
  
  // Priority 4: CTA text/border colors (fallback)
  if (!brandPrimary) {
    const ctaTextColors = [
      ...data.buttonColors.filter(s => s.frequency >= 1.2),
      ...data.linkColors.filter(s => s.frequency >= 1.5)
    ]
      .filter(s => {
        const sat = getSaturation(s.color);
        return sat > 0.3 && !isNearGrayscale(s.color);
      })
      .sort((a, b) => b.frequency - a.frequency);
    
    if (ctaTextColors.length > 0) {
      brandPrimary = ctaTextColors[0].color;
    }
  }
  
  // Priority 5: High-saturation accent colors (buttons/links/hero)
  if (!brandPrimary) {
    const highSatColors = getHighSaturationColors([
      ...data.buttonColors,
      ...data.linkColors
    ], 0.3);
    
    if (highSatColors.length > 0) {
      brandPrimary = highSatColors[0].color;
    }
  }
  
  // Fallback to default if still no brand color
  if (!brandPrimary) {
    brandPrimary = '#2563eb';
  }
  
  // 4. Brand Secondary - Priority Model (Phase 3.9)
  let brandSecondary: string | undefined;
  
  // Priority 1: Remaining brand-related CSS variable colors
  const secondaryCssVarKeys = [
    '--brand-secondary',
    '--secondary',
    '--color-secondary',
    '--accent',
    '--theme-secondary'
  ];
  
  for (const key of secondaryCssVarKeys) {
    const value = cssVarMap[key];
    if (value && value !== brandPrimary) {
      const sat = getSaturation(value);
      if (sat > 0.2 && !isNearGrayscale(value)) {
        const hueDiff = getHueDifference(brandPrimary, value);
        if (hueDiff > 30) { // Ensure different hue
          brandSecondary = value;
          break;
        }
      }
    }
  }
  
  // Priority 2: Second-highest saturation color (different hue than primary)
  if (!brandSecondary) {
    const highSatColors = getHighSaturationColors([
      ...data.buttonColors,
      ...data.linkColors
    ], 0.3);
    
    for (const sample of highSatColors) {
      if (sample.color !== brandPrimary) {
        const hueDiff = getHueDifference(brandPrimary, sample.color);
        if (hueDiff > 30) { // Ensure different hue
          brandSecondary = sample.color;
          break;
        }
      }
    }
  }
  
  // Priority 3: Nav hover/focus / secondary CTA colors
  if (!brandSecondary) {
    const navColors = data.linkColors
      .filter(s => s.frequency >= 1.2 && s.color !== brandPrimary)
      .filter(s => {
        const sat = getSaturation(s.color);
        return sat > 0.25;
      })
      .sort((a, b) => b.frequency - a.frequency);
    
    if (navColors.length > 0) {
      const candidate = navColors[0].color;
      const hueDiff = getHueDifference(brandPrimary, candidate);
      if (hueDiff > 20) {
        brandSecondary = candidate;
      }
    }
  }
  
  // Priority 4: Any distinct hue with sufficient contrast vs background and brandPrimary
  if (!brandSecondary) {
    const candidates = getHighSaturationColors([
      ...data.buttonColors,
      ...data.linkColors
    ], 0.25);
    
    for (const sample of candidates) {
      if (sample.color !== brandPrimary) {
        const hueDiff = getHueDifference(brandPrimary, sample.color);
        const contrast = getContrastRatio(sample.color, background);
        
        if (hueDiff > 20 && contrast >= 2.5) {
          brandSecondary = sample.color;
          break;
        }
      }
    }
  }
  
  // 5. Text Primary - dark color with good contrast
  let textPrimary = '#111827';
  const darkColors = getDarkColors([
    ...data.linkColors,
    ...allSamples.filter(s => s.source === 'background' && getBrightness(s.color) < 0.3)
  ]);
  
  if (darkColors.length > 0) {
    const candidate = darkColors[0].color;
    // Ensure good contrast
    const contrast = getContrastRatio(candidate, background);
    if (contrast >= 4.5) {
      textPrimary = candidate;
    }
  } else {
    // Fallback: ensure contrast
    const darkContrast = getContrastRatio('#000000', background);
    const lightContrast = getContrastRatio('#ffffff', background);
    textPrimary = darkContrast > lightContrast ? '#000000' : '#ffffff';
  }
  
  // 6. Text Secondary - slightly lighter than text primary
  let textSecondary: string | undefined;
  const mediumColors = allSamples.filter(s => {
    const brightness = getBrightness(s.color);
    return brightness > 0.3 && brightness < 0.7;
  });
  if (mediumColors.length > 0) {
    textSecondary = mediumColors[0].color;
  } else {
    // Generate a lighter version
    const rgb = hexToRgb(textPrimary);
    if (rgb) {
      const r = Math.min(255, rgb.r + 60);
      const g = Math.min(255, rgb.g + 60);
      const b = Math.min(255, rgb.b + 60);
      textSecondary = `#${((r << 16) | (g << 8) | b).toString(16).padStart(6, '0')}`;
    }
  }
  
  // 7. Accent - Priority Model (Phase 3.9)
  let accent: string | undefined;
  
  // Priority 1: Distinct non-brand hue with medium-high saturation
  const accentCandidates = getHighSaturationColors([
    ...data.buttonColors,
    ...data.linkColors
  ], 0.25)
    .filter(s => 
      s.color !== brandPrimary && 
      s.color !== brandSecondary &&
      s.color !== textPrimary
    );
  
  for (const sample of accentCandidates) {
    const hueDiffPrimary = getHueDifference(brandPrimary, sample.color);
    const hueDiffSecondary = brandSecondary ? getHueDifference(brandSecondary, sample.color) : 100;
    
    if (hueDiffPrimary > 30 && hueDiffSecondary > 20) {
      accent = sample.color;
      break;
    }
  }
  
  // Priority 2: Secondary CTA or highlight colors
  if (!accent) {
    const highlightColors = [
      ...data.buttonColors.filter(s => s.frequency >= 1.2),
      ...data.linkColors.filter(s => s.frequency >= 1.2)
    ]
      .filter(s => {
        const sat = getSaturation(s.color);
        return sat > 0.3 && 
               s.color !== brandPrimary && 
               s.color !== brandSecondary;
      })
      .sort((a, b) => b.frequency - a.frequency);
    
    if (highlightColors.length > 0) {
      accent = highlightColors[0].color;
    }
  }
  
  // Priority 3: Link hover colors (warm or bright)
  if (!accent) {
    const warmColors = accentCandidates.filter(s => {
      const rgb = hexToRgb(s.color);
      if (!rgb) return false;
      // Prefer warm colors (red/orange/yellow)
      const hue = getHue(s.color);
      return (hue >= 0 && hue <= 60) || (hue >= 300 && hue <= 360);
    });
    
    if (warmColors.length > 0) {
      accent = warmColors[0].color;
    }
  }
  
  return {
    background,
    surface,
    textPrimary,
    textSecondary,
    brandPrimary,
    brandSecondary,
    accent,
    logo: data.logoHint
  };
}

// Helper functions
function hexToRgb(hex: string): { r: number; g: number; b: number } | null {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result
    ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
      }
    : null;
}

function getBrightness(hex: string): number {
  const rgb = hexToRgb(hex);
  if (!rgb) return 0;
  
  const { r, g, b } = rgb;
  return (r * 299 + g * 587 + b * 114) / 1000 / 255;
}

function getContrastRatio(foregroundHex: string, backgroundHex: string): number {
  const lum1 = getLuminance(foregroundHex);
  const lum2 = getLuminance(backgroundHex);
  const lighter = Math.max(lum1, lum2);
  const darker = Math.min(lum1, lum2);
  return (lighter + 0.05) / (darker + 0.05);
}

function getLuminance(hex: string): number {
  const rgb = hexToRgb(hex);
  if (!rgb) return 0;
  
  const [r, g, b] = [rgb.r, rgb.g, rgb.b].map((val) => {
    val = val / 255;
    return val <= 0.03928 ? val / 12.92 : Math.pow((val + 0.055) / 1.055, 2.4);
  });
  
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/**
 * Calculates hue difference between two colors (0-180 degrees)
 */
function getHueDifference(hex1: string, hex2: string): number {
  const hue1 = getHue(hex1);
  const hue2 = getHue(hex2);
  const diff = Math.abs(hue1 - hue2);
  return Math.min(diff, 360 - diff); // Wrap around
}

/**
 * Calculates hue of a color (0-360 degrees)
 */
function getHue(hex: string): number {
  const rgb = hexToRgb(hex);
  if (!rgb) return 0;
  
  const { r, g, b } = rgb;
  const rNorm = r / 255;
  const gNorm = g / 255;
  const bNorm = b / 255;
  
  const max = Math.max(rNorm, gNorm, bNorm);
  const min = Math.min(rNorm, gNorm, bNorm);
  const delta = max - min;
  
  if (delta === 0) return 0; // Grayscale
  
  let hue = 0;
  if (max === rNorm) {
    hue = ((gNorm - bNorm) / delta) % 6;
  } else if (max === gNorm) {
    hue = (bNorm - rNorm) / delta + 2;
  } else {
    hue = (rNorm - gNorm) / delta + 4;
  }
  
  hue = hue * 60;
  if (hue < 0) hue += 360;
  
  return hue;
}
