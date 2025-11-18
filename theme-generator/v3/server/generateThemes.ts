import type { SiteSnapshot } from '../src/types/siteSnapshot';
import type { ThemeTokensLite } from '../src/types/theme';

function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Phase 4.7: Helper to create enhanced typography structure with fallbacks
 */
function createTypographyStructure(typography: SiteSnapshot['typography']): ThemeTokensLite['typography'] {
  const baseFontSize = typography.baseFontSizePx || 14;
  const headingSize = Math.round(baseFontSize * 1.3);
  const bodyFontFamily = typography.bodyFontFamily || 'system-ui, sans-serif';
  const headingFontFamily = typography.headingFontFamily || bodyFontFamily;
  
  return {
    fontFamilyBase: bodyFontFamily,
    fontFamilyHeading: headingFontFamily,
    baseFontSize,
    headingSize,
    bodySize: baseFontSize,
    buttonSize: baseFontSize,
    // Phase 4.7: Enhanced typography roles
    heading: {
      fontFamily: headingFontFamily,
      fontSize: headingSize,
      fontWeight: 600,
      lineHeight: 1.3
    },
    body: {
      fontFamily: bodyFontFamily,
      fontSize: baseFontSize,
      fontWeight: 400,
      lineHeight: 1.5
    },
    button: {
      fontFamily: bodyFontFamily,
      fontSize: baseFontSize,
      fontWeight: 600,
      letterSpacing: 0.5,
      lineHeight: 1.4
    }
  };
}

/**
 * Phase 4.7: Helper to create enhanced layout structure with defaults
 */
function createLayoutStructure(borderRadius: number = 8, spacingMd: number = 12): ThemeTokensLite['layout'] {
  return {
    borderRadius,
    spacingMd,
    // Phase 4.7: Enhanced layout tokens
    borderRadiusTokens: {
      widget: borderRadius,
      button: borderRadius,
      option: borderRadius,
      input: 4
    },
    spacing: {
      optionGap: spacingMd,
      widgetPadding: 24,
      sectionSpacing: 20
    },
    maxWidth: {
      widget: 420
    }
  };
}

/**
 * Generates 4 theme variants from a SiteSnapshot
 */
export function generateThemesFromSnapshot(snapshot: SiteSnapshot): ThemeTokensLite[] {
  const { detectedColors, typography } = snapshot;
  
  // Helper to lighten a color (simple approach)
  function lightenColor(hex: string, percent: number): string {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = (num >> 16) & 0xff;
    const g = (num >> 8) & 0xff;
    const b = num & 0xff;
    const newR = Math.min(255, Math.round(r + (255 - r) * percent));
    const newG = Math.min(255, Math.round(g + (255 - g) * percent));
    const newB = Math.min(255, Math.round(b + (255 - b) * percent));
    return `#${((newR << 16) | (newG << 8) | newB).toString(16).padStart(6, '0')}`;
  }
  
  // Helper to darken a color
  function darkenColor(hex: string, percent: number): string {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = (num >> 16) & 0xff;
    const g = (num >> 8) & 0xff;
    const b = num & 0xff;
    const newR = Math.max(0, Math.round(r * (1 - percent)));
    const newG = Math.max(0, Math.round(g * (1 - percent)));
    const newB = Math.max(0, Math.round(b * (1 - percent)));
    return `#${((newR << 16) | (newG << 8) | newB).toString(16).padStart(6, '0')}`;
  }
  
  // Default brand colors if not detected
  const brandPrimary = detectedColors.brandPrimary || '#2563eb';
  const brandSecondary = detectedColors.brandSecondary || '#9333ea';
  
  // 1. Brand Faithful
  const brandFaithful: ThemeTokensLite = {
    id: generateId(),
    name: 'Brand Faithful',
    variantType: 'brand-faithful',
    
    palette: {
      background: detectedColors.background || '#ffffff',
      surface: detectedColors.surface || lightenColor(detectedColors.background || '#ffffff', 0.05),
      surfaceAlt: lightenColor(detectedColors.background || '#ffffff', 0.1),
      textPrimary: detectedColors.textPrimary || '#111827',
      textSecondary: detectedColors.textSecondary || '#4b5563',
      brandPrimary,
      brandSecondary,
      accent: detectedColors.accent || '#f97316',
      danger: '#dc2626',
      success: '#16a34a'
    },
    
    typography: createTypographyStructure(typography),
    
    components: {
      widget: {
        headerBg: detectedColors.background || '#ffffff',
        headerText: detectedColors.textPrimary || '#111827',
        bodyBg: detectedColors.background || '#ffffff',
        bodyText: detectedColors.textPrimary || '#111827',
        borderColor: '#e5e7eb'
      },
      singleChoice: {
        bgDefault: detectedColors.surface || lightenColor(detectedColors.background || '#ffffff', 0.05),
        bgActive: brandPrimary,
        textDefault: detectedColors.textPrimary || '#111827',
        textActive: '#ffffff',
        borderDefault: brandPrimary,
        borderActive: brandPrimary
      },
      ctaButton: {
        bg: brandPrimary,
        text: '#ffffff',
        bgHover: brandSecondary,
        textHover: '#ffffff'
      }
    },
    
    layout: createLayoutStructure(8, 12)
  };
  
  // 2. Light
  const light: ThemeTokensLite = {
    id: generateId(),
    name: 'Light',
    variantType: 'light',
    
    palette: {
      background: '#ffffff',
      surface: '#f9fafb',
      surfaceAlt: '#f3f4f6',
      textPrimary: '#111827',
      textSecondary: '#4b5563',
      brandPrimary,
      brandSecondary,
      accent: '#f97316',
      danger: '#dc2626',
      success: '#16a34a'
    },
    
    typography: createTypographyStructure(typography),
    
    components: {
      widget: {
        headerBg: '#ffffff',
        headerText: '#111827',
        bodyBg: '#ffffff',
        bodyText: '#111827',
        borderColor: '#e5e7eb'
      },
      singleChoice: {
        bgDefault: '#ffffff',
        bgActive: brandPrimary,
        textDefault: '#111827',
        textActive: '#ffffff',
        borderDefault: brandPrimary,
        borderActive: brandPrimary
      },
      ctaButton: {
        bg: brandPrimary,
        text: '#ffffff',
        bgHover: brandSecondary,
        textHover: '#ffffff'
      }
    },
    
    layout: createLayoutStructure(8, 12)
  };
  
  // 3. Dark
  const dark: ThemeTokensLite = {
    id: generateId(),
    name: 'Dark',
    variantType: 'dark',
    
    palette: {
      background: '#0f172a',
      surface: '#1e293b',
      surfaceAlt: '#334155',
      textPrimary: '#f8fafc',
      textSecondary: '#cbd5e1',
      brandPrimary: lightenColor(brandPrimary, 0.2), // Brighten brand color for dark theme
      brandSecondary: lightenColor(brandSecondary, 0.2),
      accent: '#f97316',
      danger: '#ef4444',
      success: '#22c55e'
    },
    
    typography: createTypographyStructure(typography),
    
    components: {
      widget: {
        headerBg: '#1e293b',
        headerText: '#f8fafc',
        bodyBg: '#1e293b',
        bodyText: '#f8fafc',
        borderColor: '#334155'
      },
      singleChoice: {
        bgDefault: '#1e293b',
        bgActive: lightenColor(brandPrimary, 0.2),
        textDefault: '#f8fafc',
        textActive: '#ffffff',
        borderDefault: lightenColor(brandPrimary, 0.2),
        borderActive: lightenColor(brandPrimary, 0.2)
      },
      ctaButton: {
        bg: lightenColor(brandPrimary, 0.2),
        text: '#ffffff',
        bgHover: lightenColor(brandSecondary, 0.2),
        textHover: '#ffffff'
      }
    },
    
    layout: createLayoutStructure(8, 12)
  };
  
  // 4. Minimal
  const minimal: ThemeTokensLite = {
    id: generateId(),
    name: 'Minimal',
    variantType: 'minimal',
    
    palette: {
      background: '#ffffff',
      surface: '#ffffff',
      surfaceAlt: '#f9fafb',
      textPrimary: '#111827',
      textSecondary: '#6b7280',
      brandPrimary, // Used sparingly
      brandSecondary,
      accent: '#f97316',
      danger: '#dc2626',
      success: '#16a34a'
    },
    
    typography: createTypographyStructure(typography),
    
    components: {
      widget: {
        headerBg: '#ffffff',
        headerText: '#111827',
        bodyBg: '#ffffff',
        bodyText: '#111827',
        borderColor: '#e5e7eb'
      },
      singleChoice: {
        bgDefault: '#ffffff',
        bgActive: brandPrimary,
        textDefault: '#111827',
        textActive: '#ffffff',
        borderDefault: '#e5e7eb',
        borderActive: brandPrimary
      },
      ctaButton: {
        bg: brandPrimary,
        text: '#ffffff',
        bgHover: brandSecondary,
        textHover: '#ffffff'
      }
    },
    
    layout: createLayoutStructure(6, 12)
  };
  
  return [brandFaithful, light, dark, minimal];
}

