import Color from "colorjs.io";
import { RawFinding } from "../types.js";
import { deepMergeTokens, defaultTokenValues, parseLegacyColor, legacyContrastRatio } from "../legacy/themeCompiler.js";

interface ColorCandidate {
  value: string;
  name: string;
}

const FALLBACK_PRIMARY = "#2563eb";
const FALLBACK_SECONDARY = "#1d4ed8";
const FALLBACK_BACKGROUND = "#ffffff";
const FALLBACK_TEXT = "#1f2937";

export interface PaletteOverrides {
  primary?: string | null;
  secondary?: string | null;
  background?: string | null;
  text?: string | null;
}

export function buildLegacyTokens(rawFindings: RawFinding[], overrides?: PaletteOverrides) {
  const tokens = deepMergeTokens(defaultTokenValues, {}) as Record<string, any>;
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
  ]) ?? colors[0]?.value ?? FALLBACK_PRIMARY;
  usedColors.add(primary);

  const secondary = pickColor(colors, usedColors, [
    "secondary",
    "alternate",
    "muted",
    "support",
    "logo",
  ]) ?? colors.find((candidate) => candidate.value !== primary)?.value ?? FALLBACK_SECONDARY;
  usedColors.add(secondary);

  const background =
    pickColor(colors, usedColors, ["background", "surface", "panel", "card", "body.backgroundcolor"]) ??
    getNamedColor(colors, "body.backgroundColor") ??
    FALLBACK_BACKGROUND;
  usedColors.add(background);

  const text =
    pickColor(colors, usedColors, ["text", "body.color", "font", "heading"]) ??
    getNamedColor(colors, "body.color") ??
    FALLBACK_TEXT;
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

  tokens.colors = tokens.colors ?? {};
  tokens.colors.primary = resolvedPrimary;
  tokens.colors.primaryHover = darkenColor(resolvedPrimary, 0.1);
  tokens.colors.primaryActive = darkenColor(resolvedPrimary, 0.2);
  tokens.colors.secondary = resolvedSecondary;
  tokens.colors.bg = resolvedBackground;
  tokens.colors.text = resolvedText;
  const resolvedMuted = normalizedOverrides.text ? lightenColor(resolvedText, 0.2) : mutedCandidate;
  const resolvedAnswerBorder = normalizedOverrides.primary ? lightenColor(resolvedPrimary, 0.35) : answerBorderCandidate;

  tokens.colors.muted = resolvedMuted;
  tokens.colors.answerBorder = resolvedAnswerBorder;
  tokens.colors.inputBorder = lightenColor(resolvedPrimary, 0.4);
  tokens.colors.inputFocus = lightenColor(resolvedPrimary, 0.15);

  tokens.typography = tokens.typography ?? {};
  tokens.typography.fontFamily = fonts[0] ?? tokens.typography.fontFamily;

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

function ensureOnPrimary(tokens: Record<string, any>) {
  const primary = parseLegacyColor(tokens.colors?.primary);
  if (!primary) {
    tokens.colors.onPrimary = "#ffffff";
    return;
  }
  const white = parseLegacyColor("#ffffff");
  const dark = parseLegacyColor("#111827");
  const whiteContrast = legacyContrastRatio(primary, white);
  const darkContrast = legacyContrastRatio(primary, dark);
  tokens.colors.onPrimary = whiteContrast >= darkContrast ? "#ffffff" : "#111827";
}
