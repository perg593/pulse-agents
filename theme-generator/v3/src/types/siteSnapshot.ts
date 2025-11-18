export interface SiteSnapshot {
  url: string;
  pageTitle?: string;
  screenshotUrl?: string; // Base64 data URL or URL to screenshot
  detectedColors: {
    background: string;
    surface?: string;
    textPrimary: string;
    textSecondary?: string;
    brandPrimary?: string;
    brandSecondary?: string;
    accent?: string;
    logo?: string; // Dominant color extracted from logo region
  };
  typography: {
    bodyFontFamily: string;
    headingFontFamily: string;
    baseFontSizePx: number;
  };
}

export interface AnalyzeSiteRequest {
  url: string;
  maxPages: number;
}

export interface AnalyzeSiteResponse {
  snapshot: SiteSnapshot;
  themes: import('./theme').ThemeTokensLite[];
}

