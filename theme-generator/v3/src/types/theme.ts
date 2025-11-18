export interface ThemeTokensLite {
  id: string;
  name: string;
  variantType: 'custom' | 'brand-faithful' | 'light' | 'dark' | 'minimal';
  
  palette: {
    background: string;
    surface: string;
    surfaceAlt: string;
    textPrimary: string;
    textSecondary: string;
    brandPrimary: string;
    brandSecondary: string;
    accent: string;
    danger: string;
    success: string;
  };
  
  typography: {
    // Phase 4.7: Enhanced typography structure (backward compatible)
    fontFamilyBase: string;
    fontFamilyHeading?: string;
    baseFontSize: number;
    headingSize: number;
    bodySize: number;
    buttonSize: number;
    // Phase 4.7: New structured typography roles
    heading?: {
      fontFamily: string;
      fontSize: number;     // px
      fontWeight: number;   // 400, 500, 600, 700
      lineHeight?: number;  // unitless multiple
    };
    body?: {
      fontFamily: string;
      fontSize: number;
      fontWeight: number;
      lineHeight?: number;
    };
    button?: {
      fontFamily: string;
      fontSize: number;
      fontWeight: number;
      letterSpacing?: number; // px
      lineHeight?: number;
    };
  };
  
  components: {
    widget: {
      headerBg: string;
      headerText: string;
      bodyBg: string;
      bodyText: string;
      borderColor: string;
    };
    singleChoice: {
      bgDefault: string;
      bgActive: string;
      textDefault: string;
      textActive: string;
      borderDefault: string;
      borderActive: string;
    };
    ctaButton: {
      bg: string;
      text: string;
      bgHover: string;
      textHover: string;
    };
  };
  
  layout: {
    // Phase 4.7: Enhanced layout structure (backward compatible)
    borderRadius: number;
    spacingMd: number;
    // Phase 4.7: New structured layout tokens
    borderRadiusTokens?: {
      widget: number;   // px
      button: number;
      option: number;
      input: number;
    };
    spacing?: {
      optionGap: number;     // px
      widgetPadding: number; // px
      sectionSpacing: number;
    };
    maxWidth?: {
      widget: number; // px
    };
  };
}

export interface ThemeProject {
  id: string;
  name: string;
  sourceUrl?: string;
  screenshotUrl?: string; // Screenshot from analysis for context mode
  createdAt: string;
  updatedAt: string;
  themes: ThemeTokensLite[];
  activeThemeId: string;
  extractedColors?: string[]; // Colors extracted from site analysis
  // Phase 4.6: Baseline themes (deep copy of theme when first created/generated)
  baselineThemes?: Record<string, ThemeTokensLite>; // themeId -> baseline theme
}

export interface ThemeAppState {
  projects: ThemeProject[];
  activeProjectId: string | null;
}

export type Viewport = 'desktop' | 'mobile';

// Phase 4.0: Device types for Canvas
export type DeviceType = 'desktop' | 'iphone' | 'android';

export const VIEWPORT_WIDTHS: Record<Viewport, number> = {
  desktop: 1280,
  mobile: 375
};

// Phase 4.0: Device widths for Canvas
export const DEVICE_WIDTHS: Record<DeviceType, number> = {
  desktop: 1280,
  iphone: 375,
  android: 360
};
