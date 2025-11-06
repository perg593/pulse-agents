/**
 * Constants used throughout the Pulse Theme Generator v2
 */

/**
 * Matching thresholds for fuzzy name matching
 */
export const MATCHING_THRESHOLDS = {
  /** Minimum fuzzy match score to consider a match (0-1) */
  FUZZY_MATCH_MIN: 0.5,
  /** Exact variable match confidence */
  EXACT_VARIABLE_CONFIDENCE: 0.95,
  /** Exact name match confidence */
  EXACT_NAME_CONFIDENCE: 0.85,
  /** Fuzzy match confidence base */
  FUZZY_MATCH_BASE_CONFIDENCE: 0.55,
} as const;

/**
 * Confidence scores for different evidence types
 */
export const EVIDENCE_CONFIDENCE = {
  /** Derived evidence (heuristic-based) */
  DERIVED: 0.3,
  /** Computed style evidence */
  COMPUTED: 0.4,
  /** Logo color evidence */
  LOGO: 0.6,
  /** High priority selector (:root) */
  ROOT_SELECTOR: 0.85,
  /** Medium priority selectors (html, body) */
  BODY_SELECTOR: 0.7,
  /** Default selector confidence */
  DEFAULT_SELECTOR: 0.55,
} as const;

/**
 * Logo extraction limits
 */
export const LOGO_LIMITS = {
  /** Maximum number of logos to process per page */
  MAX_LOGOS_PER_PAGE: 5,
  /** Maximum colors to extract from each logo */
  MAX_COLORS_PER_LOGO: 6,
  /** Maximum SVG colors to extract */
  MAX_SVG_COLORS: 8,
} as const;

/**
 * Image sampling thresholds
 */
export const IMAGE_SAMPLING = {
  /** Maximum width for logo image sampling (pixels) */
  MAX_SAMPLE_WIDTH: 64,
  /** Minimum pixel count threshold for color bucket (as percentage of area) */
  MIN_COUNT_PERCENTAGE: 0.008,
  /** Minimum absolute pixel count for color bucket */
  MIN_COUNT_ABSOLUTE: 6,
  /** Minimum saturation threshold for color inclusion (0-1) */
  MIN_SATURATION: 0.12,
  /** Color similarity threshold for duplicate detection (RGB distance) */
  DUPLICATE_THRESHOLD: 35,
} as const;

/**
 * Palette derivation settings
 */
export const PALETTE_DERIVATION = {
  /** Maximum colors before palette derivation is skipped */
  MAX_COLORS_BEFORE_DERIVATION: 6,
  /** OKLCH lightness deltas for tonal scale steps */
  TONAL_STEPS: [
    { suffix: "50", delta: 0.35 },
    { suffix: "100", delta: 0.25 },
    { suffix: "200", delta: 0.18 },
    { suffix: "300", delta: 0.1 },
    { suffix: "400", delta: 0.05 },
    { suffix: "500", delta: 0 },
    { suffix: "600", delta: -0.05 },
    { suffix: "700", delta: -0.1 },
    { suffix: "800", delta: -0.18 },
    { suffix: "900", delta: -0.28 },
  ] as const,
  /** OKLCH lightness bounds (0-1) */
  LIGHTNESS_BOUNDS: { min: 0.08, max: 0.98 } as const,
} as const;

/**
 * Browser extraction settings
 */
export const EXTRACTION_SETTINGS = {
  /** Default timeout for page navigation (milliseconds) */
  DEFAULT_TIMEOUT_MS: 45000,
  /** Maximum custom properties to extract per selector */
  MAX_CUSTOM_PROPS_PER_SELECTOR: 40,
  /** URL discovery multiplier (limit * MULTIPLIER = candidates to check) */
  URL_DISCOVERY_MULTIPLIER: 3,
} as const;

/**
 * Default color values for fallbacks
 */
export const DEFAULT_COLORS = {
  PRIMARY: "#2563eb",
  SECONDARY: "#1d4ed8",
  BACKGROUND: "#ffffff",
  TEXT: "#1f2937",
  ON_PRIMARY_LIGHT: "#ffffff",
  ON_PRIMARY_DARK: "#111827",
} as const;

