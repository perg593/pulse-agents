/**
 * Converts hex color to RGB
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
 * Calculates relative luminance of a color
 * Based on WCAG 2.1 formula
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
 * Calculates contrast ratio between two colors
 * Returns a value between 1 (no contrast) and 21 (maximum contrast)
 * WCAG AA requires 4.5:1 for normal text, 3:1 for large text
 * WCAG AAA requires 7:1 for normal text, 4.5:1 for large text
 */
export function getContrastRatio(foregroundHex: string, backgroundHex: string): number {
  const lum1 = getLuminance(foregroundHex);
  const lum2 = getLuminance(backgroundHex);

  const lighter = Math.max(lum1, lum2);
  const darker = Math.min(lum1, lum2);

  return (lighter + 0.05) / (darker + 0.05);
}

/**
 * Gets contrast status based on WCAG guidelines
 */
export function getContrastStatus(ratio: number, isLargeText: boolean = false): {
  status: 'pass-aa' | 'pass-aaa' | 'fail';
  label: string;
  icon: string;
} {
  if (isLargeText) {
    if (ratio >= 4.5) {
      return { status: 'pass-aaa', label: 'Pass (AAA)', icon: '✅' };
    } else if (ratio >= 3) {
      return { status: 'pass-aa', label: 'Pass (AA)', icon: '✅' };
    } else {
      return { status: 'fail', label: 'Fail', icon: '⚠️' };
    }
  } else {
    if (ratio >= 7) {
      return { status: 'pass-aaa', label: 'Pass (AAA)', icon: '✅' };
    } else if (ratio >= 4.5) {
      return { status: 'pass-aa', label: 'Pass (AA)', icon: '✅' };
    } else {
      return { status: 'fail', label: 'Fail', icon: '⚠️' };
    }
  }
}

