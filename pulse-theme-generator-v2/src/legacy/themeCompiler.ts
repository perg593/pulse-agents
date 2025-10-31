import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
// eslint-disable-next-line @typescript-eslint/no-var-requires
const legacyCompiler = require("../../../theme-generator/src/theme-css.js") as {
  compileTheme: (
    rawTheme?: Record<string, unknown>,
    options?: Record<string, unknown>,
  ) => { css: string | null; theme: Record<string, unknown>; warnings: string[]; errors: string[] };
  DEFAULTS: Record<string, unknown>;
  REQUIRED_FIELDS: unknown;
  parseColor: (value: unknown) => { r: number; g: number; b: number } | null;
  contrastRatio: (a: { r: number; g: number; b: number } | null, b: { r: number; g: number; b: number } | null) => number;
  deepMerge: (target?: Record<string, unknown>, source?: Record<string, unknown>) => Record<string, unknown>;
};

export const compileTheme = legacyCompiler.compileTheme;
export const defaultTokenValues = legacyCompiler.DEFAULTS;
export const requiredFields = legacyCompiler.REQUIRED_FIELDS;
export const parseLegacyColor = legacyCompiler.parseColor;
export const legacyContrastRatio = legacyCompiler.contrastRatio;
export const deepMergeTokens = legacyCompiler.deepMerge;

export type LegacyCompileResult = ReturnType<typeof compileTheme>;
