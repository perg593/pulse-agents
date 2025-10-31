import Color from "colorjs.io";
import { RawFinding } from "../types.js";
import { deepMergeTokens, defaultTokenValues, parseLegacyColor, legacyContrastRatio } from "../legacy/themeCompiler.js";
import { DEFAULT_COLORS } from "../utils/constants.js";

interface ColorCandidate {
  value: string;
  name: string;
}

export interface PaletteOverrides {
  primary?: string | null;
  secondary?: string | null;
  background?: string | null;
  text?: string | null;
}

/**
 * Builds legacy Pulse widget tokens from raw findings.
 * Extracts colors and fonts, applies overrides if provided, and ensures
 * proper contrast ratios for accessibility.
 *
 * @param rawFindings - Raw findings extracted from the target website
 * @param overrides - Optional palette overrides for primary, secondary, background, and text colors
 * @returns Legacy token object compatible with Pulse widget theme compiler
 *
 * @example
 * ```typescript
 * const tokens = buildLegacyTokens(rawFindings, {
 *   primary: "#ff0000",
 *   background: "#ffffff"
 * });
 * const css = compileTheme(tokens);
 * ```
 */
export function buildLegacyTokens(rawFindings: RawFinding[], overrides?: PaletteOverrides): Record<string, unknown> {
  const tokens = deepMergeTokens(defaultTokenValues, {}) as Record<string, unknown>;
  const colors = collectColorCandidates(rawFindings);
  const fonts = collectFontCandidates(rawFindings);

  const usedColors = new Set<string>();

  const primary = pickColor(colors, usedColors, [
    "primary",
    "brand",
    "accent",
    "cta",
    "button",
    "link",
    "logo",
  ]) ?? colors[0]?.value ?? DEFAULT_COLORS.PRIMARY;
  usedColors.add(primary);

  const secondary = pickColor(colors, usedColors, [
    "secondary",
    "alternate",
    "muted",
    "support",
    "logo",
  ]) ?? colors.find((candidate) => candidate.value !== primary)?.value ?? DEFAULT_COLORS.SECONDARY;
  usedColors.add(secondary);

  const background =
    pickColor(colors, usedColors, ["background", "surface", "panel", "card", "body.backgroundcolor"]) ??
    getNamedColor(colors, "body.backgroundColor") ??
    DEFAULT_COLORS.BACKGROUND;
  usedColors.add(background);

  const text =
    pickColor(colors, usedColors, ["text", "body.color", "font", "heading"]) ??
    getNamedColor(colors, "body.color") ??
    DEFAULT_COLORS.TEXT;
  usedColors.add(text);

  const mutedCandidate =
    pickColor(colors, usedColors, ["muted", "subtle", "secondarytext"]) ??
    lightenColor(text, 0.2);

  const answerBorderCandidate =
    pickColor(colors, usedColors, ["border", "outline", "divider"]) ??
    lightenColor(primary, 0.35);

  const normalizedOverrides = {
    primary: normalizeColor(overrides?.primary ?? "") ?? overrides?.primary ?? null,
    secondary: normalizeColor(overrides?.secondary ?? "") ?? overrides?.secondary ?? null,
    background: normalizeColor(overrides?.background ?? "") ?? overrides?.background ?? null,
    text: normalizeColor(overrides?.text ?? "") ?? overrides?.text ?? null,
  };

  const resolvedPrimary = normalizedOverrides.primary ?? primary;
  const resolvedSecondary = normalizedOverrides.secondary ?? secondary;
  const resolvedBackground = normalizedOverrides.background ?? background;
  const resolvedText = normalizedOverrides.text ?? text;

  const colorsObj = (tokens.colors as Record<string, unknown>) ?? {};
  colorsObj.primary = resolvedPrimary;
  colorsObj.primaryHover = darkenColor(resolvedPrimary, 0.1);
  colorsObj.primaryActive = darkenColor(resolvedPrimary, 0.2);
  colorsObj.secondary = resolvedSecondary;
  colorsObj.bg = resolvedBackground;
  colorsObj.text = resolvedText;
  const resolvedMuted = normalizedOverrides.text ? lightenColor(resolvedText, 0.2) : mutedCandidate;
  const resolvedAnswerBorder = normalizedOverrides.primary ? lightenColor(resolvedPrimary, 0.35) : answerBorderCandidate;

  colorsObj.muted = resolvedMuted;
  colorsObj.answerBorder = resolvedAnswerBorder;
  colorsObj.inputBorder = lightenColor(resolvedPrimary, 0.4);
  colorsObj.inputFocus = lightenColor(resolvedPrimary, 0.15);
  tokens.colors = colorsObj;

  const typographyObj = (tokens.typography as Record<string, unknown>) ?? {};
  typographyObj.fontFamily = fonts[0] ?? typographyObj.fontFamily;
  tokens.typography = typographyObj;

  ensureOnPrimary(tokens);
  return tokens;
}

function collectColorCandidates(rawFindings: RawFinding[]): ColorCandidate[] {
  const candidates: ColorCandidate[] = [];
  const seen = new Set<string>();
  for (const finding of rawFindings) {
    if (finding.category !== "color") continue;
    const hex = normalizeColor(finding.value);
    if (!hex) continue;
    if (seen.has(hex)) continue;
    seen.add(hex);
    candidates.push({ value: hex, name: finding.normalizedName.toLowerCase() });
  }
  return candidates;
}

function collectFontCandidates(rawFindings: RawFinding[]): string[] {
  const fonts: string[] = [];
  const seen = new Set<string>();
  for (const finding of rawFindings) {
    if (finding.category !== "font") continue;
    const value = finding.value.trim();
    if (!value) continue;
    if (seen.has(value)) continue;
    seen.add(value);
    fonts.push(value);
  }
  return fonts;
}

function pickColor(
  colors: ColorCandidate[],
  used: Set<string>,
  keywords: string[],
): string | null {
  for (const keyword of keywords) {
    const match = colors.find((candidate) => candidate.name.includes(keyword) && !used.has(candidate.value));
    if (match) {
      return match.value;
    }
  }
  return null;
}

function getNamedColor(colors: ColorCandidate[], name: string): string | null {
  const match = colors.find((candidate) => candidate.name === name.toLowerCase());
  return match ? match.value : null;
}

function normalizeColor(input: string): string | null {
  if (!input) return null;
  try {
    const color = new Color(input);
    return color.to("srgb").toString({ format: "hex" }).toLowerCase();
  } catch {
    return null;
  }
}

function lightenColor(color: string, amount: number): string {
  try {
    const base = new Color(color);
    const target = base.clone().set("oklch.l", clamp(base.oklch.l + amount));
    return target.to("srgb").toString({ format: "hex" }).toLowerCase();
  } catch {
    return color;
  }
}

function darkenColor(color: string, amount: number): string {
  try {
    const base = new Color(color);
    const target = base.clone().set("oklch.l", clamp(base.oklch.l - amount));
    return target.to("srgb").toString({ format: "hex" }).toLowerCase();
  } catch {
    return color;
  }
}

function clamp(value: number, min = 0, max = 1) {
  return Math.max(min, Math.min(max, value));
}

function ensureOnPrimary(tokens: Record<string, unknown>): void {
  const colors = tokens.colors as Record<string, unknown> | undefined;
  if (!colors) {
    return;
  }
  const primary = parseLegacyColor(colors.primary as string | undefined);
  if (!primary) {
    colors.onPrimary = DEFAULT_COLORS.ON_PRIMARY_LIGHT;
    return;
  }
  const white = parseLegacyColor(DEFAULT_COLORS.ON_PRIMARY_LIGHT);
  const dark = parseLegacyColor(DEFAULT_COLORS.ON_PRIMARY_DARK);
  const whiteContrast = legacyContrastRatio(primary, white);
  const darkContrast = legacyContrastRatio(primary, dark);
  colors.onPrimary = whiteContrast >= darkContrast ? DEFAULT_COLORS.ON_PRIMARY_LIGHT : DEFAULT_COLORS.ON_PRIMARY_DARK;
}
