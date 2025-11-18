/**
 * Color extraction utilities for Phase 3.7
 */

export interface ColorSample {
  color: string;
  frequency: number;
  source: 'css-variable' | 'button' | 'link' | 'background' | 'surface' | 'logo';
}

export interface ExtractionData {
  cssVariables: Record<string, string>;
  buttonColors: ColorSample[];
  linkColors: ColorSample[];
  backgroundCandidates: ColorSample[];
  surfaceCandidates: ColorSample[];
  logoHint?: string;
}

/**
 * Converts RGB/RGBA string to hex
 */
export function rgbToHex(rgb: string): string {
  if (rgb.startsWith('#')) return rgb;
  if (rgb.startsWith('rgb')) {
    const match = rgb.match(/\d+/g);
    if (match && match.length >= 3) {
      const r = parseInt(match[0]).toString(16).padStart(2, '0');
      const g = parseInt(match[1]).toString(16).padStart(2, '0');
      const b = parseInt(match[2]).toString(16).padStart(2, '0');
      return `#${r}${g}${b}`;
    }
  }
  return rgb;
}

/**
 * Checks if a color is near grayscale (low saturation)
 */
export function isNearGrayscale(hex: string): boolean {
  const rgb = hexToRgb(hex);
  if (!rgb) return true;
  
  const { r, g, b } = rgb;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const saturation = max === 0 ? 0 : (max - min) / max;
  
  // Consider grayscale if saturation < 0.1
  return saturation < 0.1;
}

/**
 * Converts hex to RGB
 */
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

/**
 * Calculates saturation of a color
 */
export function getSaturation(hex: string): number {
  const rgb = hexToRgb(hex);
  if (!rgb) return 0;
  
  const { r, g, b } = rgb;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  return max === 0 ? 0 : (max - min) / max;
}

/**
 * Calculates brightness of a color (0-1)
 */
export function getBrightness(hex: string): number {
  const rgb = hexToRgb(hex);
  if (!rgb) return 0;
  
  const { r, g, b } = rgb;
  return (r * 299 + g * 587 + b * 114) / 1000 / 255;
}

/**
 * Calculates contrast ratio between two colors
 */
export function getContrastRatio(foregroundHex: string, backgroundHex: string): number {
  const lum1 = getLuminance(foregroundHex);
  const lum2 = getLuminance(backgroundHex);
  const lighter = Math.max(lum1, lum2);
  const darker = Math.min(lum1, lum2);
  return (lighter + 0.05) / (darker + 0.05);
}

/**
 * Calculates relative luminance (WCAG)
 */
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
 * Aggregates color samples by frequency
 */
export function aggregateColors(samples: ColorSample[]): Map<string, ColorSample> {
  const aggregated = new Map<string, ColorSample>();
  
  for (const sample of samples) {
    const normalized = sample.color.toLowerCase();
    const existing = aggregated.get(normalized);
    
    if (existing) {
      existing.frequency += sample.frequency;
    } else {
      aggregated.set(normalized, { ...sample, color: normalized });
    }
  }
  
  return aggregated;
}

/**
 * Finds most common color from samples
 */
export function getMostCommonColor(samples: ColorSample[]): string | undefined {
  if (samples.length === 0) return undefined;
  
  const aggregated = aggregateColors(samples);
  let maxFreq = 0;
  let mostCommon: ColorSample | undefined;
  
  for (const sample of aggregated.values()) {
    if (sample.frequency > maxFreq) {
      maxFreq = sample.frequency;
      mostCommon = sample;
    }
  }
  
  return mostCommon?.color;
}

/**
 * Finds colors with highest saturation (likely brand/accent colors)
 */
export function getHighSaturationColors(samples: ColorSample[], minSaturation: number = 0.3): ColorSample[] {
  return samples
    .filter(sample => getSaturation(sample.color) >= minSaturation)
    .sort((a, b) => {
      const satA = getSaturation(a.color);
      const satB = getSaturation(b.color);
      if (Math.abs(satA - satB) < 0.05) {
        // If saturation is similar, prefer higher frequency
        return b.frequency - a.frequency;
      }
      return satB - satA;
    });
}

/**
 * Finds light neutral colors (likely backgrounds)
 */
export function getLightNeutrals(samples: ColorSample[]): ColorSample[] {
  return samples
    .filter(sample => {
      const brightness = getBrightness(sample.color);
      const saturation = getSaturation(sample.color);
      return brightness > 0.85 && saturation < 0.2;
    })
    .sort((a, b) => {
      const brightA = getBrightness(a.color);
      const brightB = getBrightness(b.color);
      if (Math.abs(brightA - brightB) < 0.05) {
        return b.frequency - a.frequency;
      }
      return brightB - brightA;
    });
}

/**
 * Finds dark colors (likely text)
 */
export function getDarkColors(samples: ColorSample[]): ColorSample[] {
  return samples
    .filter(sample => {
      const brightness = getBrightness(sample.color);
      return brightness < 0.3;
    })
    .sort((a, b) => {
      const brightA = getBrightness(a.color);
      const brightB = getBrightness(b.color);
      if (Math.abs(brightA - brightB) < 0.05) {
        return b.frequency - a.frequency;
      }
      return brightA - brightB; // Darker first
    });
}

