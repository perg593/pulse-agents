import { expect, describe, it, beforeAll } from "vitest";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildTokenSchema } from "../../../pulse-theme-generator-v2/src/parser/tokenSchema.js";
import { mapFindingsToSchema } from "../../../pulse-theme-generator-v2/src/mapper/mapToSchema.js";
import { buildLegacyTokens } from "../../../pulse-theme-generator-v2/src/mapper/legacyTokenBuilder.js";
import { compileTheme } from "../../../pulse-theme-generator-v2/src/legacy/themeCompiler.js";
import { RawFinding } from "../../../pulse-theme-generator-v2/src/types.js";

const SKIP = process.env.SKIP_PUBLIC_SITE_TESTS === "1";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, "../../../pulse-theme-generator-v2");
const sassRoot = path.resolve(projectRoot, "../Old-Pulse-Themes-Framework-2025/01-css-pulse");

const fixtures = [
  {
    name: "example.com",
    dir: path.resolve(__dirname, "../../fixtures/example"),
  },
  {
    name: "web.dev",
    dir: path.resolve(__dirname, "../../fixtures/webdev"),
  },
];

(SKIP ? describe.skip : describe)("Public site extraction snapshots", () => {
  let schema: Awaited<ReturnType<typeof buildTokenSchema>>;

  beforeAll(async () => {
    schema = await buildTokenSchema({ sassRoot });
  });

  for (const fixture of fixtures) {
    it(`${fixture.name} can be mapped into Pulse tokens`, async () => {
      const rawPath = path.join(fixture.dir, "raw-findings.json");
      const raw = JSON.parse(await readFile(rawPath, "utf-8")) as RawFinding[];
      const { theme, report } = mapFindingsToSchema(schema, raw);
      const legacyTokens = buildLegacyTokens(raw);
      const compiled = compileTheme(legacyTokens);

      expect(Object.keys(theme).length).toBeGreaterThan(0);
      const mappedCount = Object.values(report).filter((entry) => entry.value).length;
      expect(mappedCount).toBeGreaterThan(0);
      expect(compiled.errors).toHaveLength(0);
      expect(compiled.css).toBeTruthy();
      expect(compiled.css).toContain("--pi-color-primary");

      expect(legacyTokens.colors?.primary).toBeTruthy();
      expect(legacyTokens.typography?.fontFamily).toBeTruthy();

      expect(theme).toMatchSnapshot(`${fixture.name}-theme`);
      const reportEntries = Object.entries(report).slice(0, 20);
      expect(Object.fromEntries(reportEntries)).toMatchSnapshot(`${fixture.name}-report-sample`);
      expect(compiled.css.slice(0, 200)).toMatchSnapshot(`${fixture.name}-css-head`);
    }, 120_000);
  }
});
