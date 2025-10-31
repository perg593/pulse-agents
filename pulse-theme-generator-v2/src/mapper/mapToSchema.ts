import { TokenSchema, TokenDescriptor } from "../parser/tokenSchema.js";
import { RawFinding, ThemeJson, ThemeReport, Evidence } from "../types.js";
import { schemaToEmptyTheme } from "../parser/tokenSchema.js";

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
    return 0.3;
  }
  if (evidence.type === "computed") {
    return 0.4;
  }
  if (evidence.type === "logo") {
    return 0.6;
  }
  const selector = "selector" in evidence && evidence.selector ? evidence.selector : "";
  for (const preferredSelector of preferred) {
    if (selector.includes(preferredSelector)) {
      switch (preferredSelector) {
        case ":root":
          return 0.85;
        case "html":
        case "body":
          return 0.7;
        default:
          return 0.65;
      }
    }
  }
  if (selector.includes(":root")) return 0.85;
  if (selector.includes("html") || selector.includes("body")) return 0.7;
  return 0.55;
}

function baseConfidence(matchType: CandidateMatch["matchType"], evidence: Evidence[], preferred: string[]): number {
  const bestSelectorConfidence = evidence.reduce((acc, item) => Math.max(acc, selectorConfidence(item, preferred)), 0);
  if (matchType === "exact-variable") {
    return Math.max(0.95, bestSelectorConfidence);
  }
  if (matchType === "exact-name") {
    return Math.max(0.85, bestSelectorConfidence);
  }
  return Math.max(0.55, bestSelectorConfidence);
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
    if (bestFuzzyScore > 0.5) {
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
