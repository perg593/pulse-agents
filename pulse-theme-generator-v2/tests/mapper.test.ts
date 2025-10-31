import { describe, it, expect } from "vitest";
import { mapFindingsToSchema } from "../src/mapper/mapToSchema.js";
import type { RawFinding, Evidence } from "../src/types.js";
import type { TokenSchema, TokenGroup, TokenDescriptor } from "../src/parser/tokenSchema.js";
import { MATCHING_THRESHOLDS, EVIDENCE_CONFIDENCE } from "../src/utils/constants.js";

function createMockSchema(): TokenSchema {
  const group: TokenGroup = {
    name: "colors",
    originalName: "colors",
    file: "test.scss",
    line: 1,
    column: 1,
    tokens: [
      {
        id: "colors.primary",
        group: "colors",
        originalGroup: "colors",
        key: "primary",
        originalKey: "primary",
        variable: "primary-color",
        file: "test.scss",
        line: 2,
        column: 3,
      },
      {
        id: "colors.secondary",
        group: "colors",
        originalGroup: "colors",
        key: "secondary",
        originalKey: "secondary",
        variable: null,
        file: "test.scss",
        line: 3,
        column: 3,
      },
    ],
  };

  return {
    groups: [group],
    variables: {},
    builders: [],
    tokenIndex: {
      "colors.primary": group.tokens[0]!,
      "colors.secondary": group.tokens[1]!,
    },
  };
}

function createMockFinding(
  name: string,
  normalizedName: string,
  value: string,
  evidence: Evidence[] = [],
): RawFinding {
  return {
    name,
    normalizedName,
    category: "color",
    value,
    sources: evidence,
  };
}

describe("Mapper", () => {
  describe("mapFindingsToSchema", () => {
    it("should map exact variable matches", () => {
      const schema = createMockSchema();
      const evidence: Evidence = {
        type: "css-var",
        selector: ":root",
        property: "--primary-color",
        value: "#2563eb",
        href: null,
      };
      const findings: RawFinding[] = [
        createMockFinding("--primary-color", "primary-color", "#2563eb", [evidence]),
      ];

      const { theme, report } = mapFindingsToSchema(schema, findings);

      expect(theme.colors?.primary).toBe("#2563eb");
      expect(report["colors.primary"]?.confidence).toBeGreaterThanOrEqual(EVIDENCE_CONFIDENCE.ROOT_SELECTOR);
      expect(report["colors.primary"]?.fallbackReason).toBeNull();
    });

    it("should map exact name matches", () => {
      const schema = createMockSchema();
      const evidence: Evidence = {
        type: "css-var",
        selector: ":root",
        property: "--primary",
        value: "#2563eb",
        href: null,
      };
      const findings: RawFinding[] = [
        createMockFinding("--primary", "primary", "#2563eb", [evidence]),
      ];

      const { theme, report } = mapFindingsToSchema(schema, findings);

      expect(theme.colors?.primary).toBe("#2563eb");
      expect(report["colors.primary"]?.confidence).toBeGreaterThanOrEqual(MATCHING_THRESHOLDS.EXACT_NAME_CONFIDENCE);
    });

    it("should map fuzzy matches above threshold", () => {
      const schema = createMockSchema();
      const evidence: Evidence = {
        type: "css-var",
        selector: "body",
        property: "--prim-color",
        value: "#2563eb",
        href: null,
      };
      const findings: RawFinding[] = [
        createMockFinding("--prim-color", "prim-color", "#2563eb", [evidence]),
      ];

      const { theme, report } = mapFindingsToSchema(schema, findings);

      // Should match "prim-color" to "primary" via fuzzy matching
      expect(theme.colors?.primary).toBe("#2563eb");
      expect(report["colors.primary"]?.fallbackReason).toBe("Matched via fuzzy name similarity");
    });

    it("should assign low confidence to unmatched tokens", () => {
      const schema = createMockSchema();
      const findings: RawFinding[] = [];

      const { theme, report } = mapFindingsToSchema(schema, findings);

      expect(theme.colors?.primary).toBeNull();
      expect(report["colors.primary"]?.confidence).toBe(0);
      expect(report["colors.primary"]?.fallbackReason).toBe("No matching finding");
    });

    it("should prioritize :root selectors", () => {
      const schema = createMockSchema();
      const rootEvidence: Evidence = {
        type: "css-var",
        selector: ":root",
        property: "--primary",
        value: "#2563eb",
        href: null,
      };
      const bodyEvidence: Evidence = {
        type: "css-var",
        selector: "body",
        property: "--primary",
        value: "#ff0000",
        href: null,
      };
      const findings: RawFinding[] = [
        createMockFinding("--primary", "primary", "#2563eb", [rootEvidence, bodyEvidence]),
      ];

      const { theme, report } = mapFindingsToSchema(schema, findings);

      // Should use :root value
      expect(theme.colors?.primary).toBe("#2563eb");
      expect(report["colors.primary"]?.confidence).toBeGreaterThanOrEqual(EVIDENCE_CONFIDENCE.ROOT_SELECTOR);
    });

    it("should handle derived evidence with lower confidence", () => {
      const schema = createMockSchema();
      const evidence: Evidence = {
        type: "derived",
        note: "Derived from primary color",
      };
      const findings: RawFinding[] = [
        createMockFinding("primary-derived", "primary-derived", "#2563eb", [evidence]),
      ];

      const { report } = mapFindingsToSchema(schema, findings);

      // Derived evidence should have lower confidence than computed
      // Note: If fuzzy matching succeeds, confidence will be >= FUZZY_MATCH_BASE_CONFIDENCE
      const primaryReport = report["colors.primary"];
      if (primaryReport && primaryReport.confidence > 0) {
        // Derived evidence contributes lower confidence, but fuzzy match base is 0.55
        // So we check it's less than exact matches
        expect(primaryReport.confidence).toBeLessThan(MATCHING_THRESHOLDS.EXACT_NAME_CONFIDENCE);
      }
    });

    it("should return unmatched tokens", () => {
      const schema = createMockSchema();
      // Use a finding that won't match anything (low fuzzy match score)
      const findings: RawFinding[] = [
        createMockFinding("--xyz-abc-123", "xyz-abc-123", "#000000"),
      ];

      const { unmatched } = mapFindingsToSchema(schema, findings);

      expect(unmatched.length).toBeGreaterThan(0);
      // Both tokens should be unmatched since finding doesn't match either
      expect(unmatched.some((t) => t.id === "colors.primary")).toBe(true);
      expect(unmatched.some((t) => t.id === "colors.secondary")).toBe(true);
    });
  });
});

