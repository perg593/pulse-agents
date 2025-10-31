import { TokenSchema, TokenDescriptor } from "../parser/tokenSchema.js";
import { RawFinding, ThemeJson, ThemeReport, Evidence } from "../types.js";
import { schemaToEmptyTheme } from "../parser/tokenSchema.js";
import { MATCHING_THRESHOLDS, EVIDENCE_CONFIDENCE } from "../utils/constants.js";

interface CandidateMatch {
  finding: RawFinding;
  token: TokenDescriptor;
  matchType: "exact-variable" | "exact-name" | "fuzzy";
  score: number;
}

interface MapFindingsOptions {
  preferredSelectors?: string[];
}

const DEFAULT_SELECTOR_PRIORITY = [
  ":root",
  "html",
  "body",
  ":root[data-theme]",
  "html[data-theme]",
  "body[data-theme]",
];

function normalizeTokenName(input: string): string {
  return input
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .toLowerCase();
}

function camelToHyphen(value: string): string {
  return value
    .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
    .replace(/_/g, "-")
    .toLowerCase();
}

function buildCandidates(token: TokenDescriptor): Set<string> {
  const names = new Set<string>();
  names.add(normalizeTokenName(token.originalKey));
  names.add(normalizeTokenName(token.key));
  names.add(normalizeTokenName(token.id));
  names.add(camelToHyphen(token.key));
  names.add(camelToHyphen(token.group));
  if (token.variable) {
    names.add(normalizeTokenName(token.variable));
  }
  const composed = `${token.group}-${token.key}`;
  names.add(normalizeTokenName(composed));
  return names;
}

function selectorConfidence(evidence: Evidence, preferred: string[]): number {
  if (evidence.type === "derived") {
    return EVIDENCE_CONFIDENCE.DERIVED;
  }
  if (evidence.type === "computed") {
    return EVIDENCE_CONFIDENCE.COMPUTED;
  }
  if (evidence.type === "logo") {
    return EVIDENCE_CONFIDENCE.LOGO;
  }
  const selector = "selector" in evidence && evidence.selector ? evidence.selector : "";
  for (const preferredSelector of preferred) {
    if (selector.includes(preferredSelector)) {
      switch (preferredSelector) {
        case ":root":
          return EVIDENCE_CONFIDENCE.ROOT_SELECTOR;
        case "html":
        case "body":
          return EVIDENCE_CONFIDENCE.BODY_SELECTOR;
        default:
          return 0.65;
      }
    }
  }
  if (selector.includes(":root")) return EVIDENCE_CONFIDENCE.ROOT_SELECTOR;
  if (selector.includes("html") || selector.includes("body")) return EVIDENCE_CONFIDENCE.BODY_SELECTOR;
  return EVIDENCE_CONFIDENCE.DEFAULT_SELECTOR;
}

function baseConfidence(matchType: CandidateMatch["matchType"], evidence: Evidence[], preferred: string[]): number {
  const bestSelectorConfidence = evidence.reduce((acc, item) => Math.max(acc, selectorConfidence(item, preferred)), 0);
  if (matchType === "exact-variable") {
    return Math.max(MATCHING_THRESHOLDS.EXACT_VARIABLE_CONFIDENCE, bestSelectorConfidence);
  }
  if (matchType === "exact-name") {
    return Math.max(MATCHING_THRESHOLDS.EXACT_NAME_CONFIDENCE, bestSelectorConfidence);
  }
  return Math.max(MATCHING_THRESHOLDS.FUZZY_MATCH_BASE_CONFIDENCE, bestSelectorConfidence);
}

function fuzzyScore(a: string, b: string): number {
  const shorter = a.length < b.length ? a : b;
  const longer = a.length < b.length ? b : a;
  if (longer.length === 0) return 1;
  let same = 0;
  for (let i = 0; i < shorter.length; i++) {
    if (longer.includes(shorter[i]!)) {
      same += 1;
    }
  }
  return same / longer.length;
}

function findBestFinding(token: TokenDescriptor, findings: RawFinding[]): CandidateMatch | null {
  const candidateNames = buildCandidates(token);
  const normalizedCandidates = Array.from(candidateNames);

  let best: CandidateMatch | null = null;

  for (const finding of findings) {
    // Exact variable match
    if (token.variable) {
      const variableName = normalizeTokenName(token.variable);
      if (finding.normalizedName === variableName || finding.name.includes(token.variable)) {
        return {
          finding,
          token,
          matchType: "exact-variable",
          score: 1,
        };
      }
    }

    if (normalizedCandidates.includes(finding.normalizedName)) {
      const score = 0.9;
      if (!best || score > best.score) {
        best = {
          finding,
          token,
          matchType: "exact-name",
          score,
        };
      }
      continue;
    }

    const fuzzyCandidates = normalizedCandidates.map((candidate) => fuzzyScore(candidate, finding.normalizedName));
    const bestFuzzyScore = Math.max(...fuzzyCandidates);
    if (bestFuzzyScore > MATCHING_THRESHOLDS.FUZZY_MATCH_MIN) {
      if (!best || bestFuzzyScore > best.score) {
        best = {
          finding,
          token,
          matchType: "fuzzy",
          score: bestFuzzyScore,
        };
      }
    }
  }

  return best;
}

function writeThemeValue(theme: ThemeJson, token: TokenDescriptor, value: string) {
  if (!(token.group in theme)) {
    theme[token.group] = {};
  }
  const group = theme[token.group] as Record<string, unknown>;
  group[token.key] = value;
}

/**
 * Maps raw findings extracted from a website onto the Pulse theme token schema.
 * Uses fuzzy matching and confidence scoring to find the best matches for each token.
 *
 * @param schema - The Pulse token schema to map findings against
 * @param findings - Raw findings extracted from the target website
 * @param options - Optional mapping configuration
 * @param options.preferredSelectors - Selectors to prioritize for confidence scoring
 * @returns Object containing the mapped theme, confidence report, and unmatched tokens
 *
 * @example
 * ```typescript
 * const { theme, report, unmatched } = mapFindingsToSchema(schema, rawFindings);
 * console.log(`Mapped ${Object.keys(theme).length} token groups`);
 * ```
 */
export function mapFindingsToSchema(
  schema: TokenSchema,
  findings: RawFinding[],
  options: MapFindingsOptions = {},
): { theme: ThemeJson; report: ThemeReport; unmatched: TokenDescriptor[] } {
  const theme: ThemeJson = schemaToEmptyTheme(schema);
  const report: ThemeReport = {};
  const preferredSelectors = options.preferredSelectors ?? DEFAULT_SELECTOR_PRIORITY;

  const matchedTokens = new Set<string>();

  for (const group of schema.groups) {
    for (const token of group.tokens) {
      const match = findBestFinding(token, findings);
      if (!match) {
        report[token.id] = {
          id: token.id,
          value: "",
          confidence: 0,
          evidence: [],
          fallbackReason: "No matching finding",
        };
        continue;
      }
      matchedTokens.add(token.id);
      const confidence = baseConfidence(match.matchType, match.finding.sources, preferredSelectors);
      writeThemeValue(theme, token, match.finding.value);
      report[token.id] = {
        id: token.id,
        value: match.finding.value,
        confidence,
        evidence: match.finding.sources,
        fallbackReason: match.matchType === "fuzzy" ? "Matched via fuzzy name similarity" : null,
        notes: match.matchType === "exact-variable" ? `Matched variable ${token.variable}` : null,
      };
    }
  }

  const unmatched = schema.groups.flatMap((group) => group.tokens.filter((token) => !matchedTokens.has(token.id)));
  return { theme, report, unmatched };
}
