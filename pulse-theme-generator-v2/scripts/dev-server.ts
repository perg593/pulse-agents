#!/usr/bin/env -S tsx
import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { mkdir, writeFile } from "node:fs/promises";
import { buildTokenSchema } from "../src/parser/tokenSchema.js";
import { extractSite, DEFAULT_GLOBAL_SELECTORS } from "../src/extractor/extractSite.js";
import { buildRawFindings } from "../src/mapper/rawFindings.js";
import { mapFindingsToSchema } from "../src/mapper/mapToSchema.js";
import type { ThemeReport, RawFinding } from "../src/types.js";
import { compileTheme } from "../src/legacy/themeCompiler.js";
import { curatedTemplate } from "../src/legacy/curatedTemplate.js";
import { buildLegacyTokens, PaletteOverrides } from "../src/mapper/legacyTokenBuilder.js";
import { loadColorDefaults, ColorDefaultGroup } from "../src/parser/colorDefaults.js";

const app = express();
app.use(express.json({ limit: "2mb" }));

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, "..");
const publicDir = path.join(projectRoot, "public");
const outputDir = path.join(projectRoot, "output");
const sassRoot = path.resolve(projectRoot, "../Old-Pulse-Themes-Framework-2025/01-css-pulse");
const sassVariablesPath = path.join(sassRoot, "_variables.scss");
let colorDefaults: ColorDefaultGroup[] = [];
try {
  colorDefaults = loadColorDefaults(sassVariablesPath);
} catch (error) {
  console.warn("Failed to load color defaults", error);
  colorDefaults = [];
}

app.use(express.static(publicDir));
app.use("/output", express.static(outputDir));

let schemaPromise = buildTokenSchema({ sassRoot });
let isBusy = false;

app.get("/api/status", async (_req, res) => {
  try {
    const schema = await schemaPromise;
    const tokenCount = schema.groups.reduce((sum, group) => sum + group.tokens.length, 0);
    res.json({
      ok: true,
      tokens: tokenCount,
      groups: schema.groups.length,
      busy: isBusy,
      sassRoot,
      colorDefaults,
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: (error as Error).message ?? "Failed to load schema",
    });
  }
});

app.post("/api/extract", async (req, res) => {
  if (isBusy) {
    res.status(409).json({ ok: false, error: "Extractor is already running. Please wait for the current job to finish." });
    return;
  }
  const { url, pages = 3, scheme = "light" } = req.body ?? {};
  if (!url || typeof url !== "string") {
    res.status(400).json({ ok: false, error: "Missing 'url' in request body" });
    return;
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(url);
  } catch {
    res.status(400).json({ ok: false, error: "Invalid URL format" });
    return;
  }

  isBusy = true;
  try {
    const schema = await schemaPromise;
    const pageLimit = Number.isFinite(pages) ? Math.max(1, Math.min(5, Number(pages))) : 3;
    const extraction = await extractSite({
      url: parsedUrl.href,
      maxPages: pageLimit,
      scheme,
    });
    const rawFindings = buildRawFindings(extraction.pages, {
      selectorPriority: DEFAULT_GLOBAL_SELECTORS,
    });
    const { theme, report } = mapFindingsToSchema(schema, rawFindings);
    const legacyTokens = buildLegacyTokens(rawFindings);
    const cssSnippet = buildCssFromLegacyCompiler(legacyTokens);
    const summary = buildThemeSummary(legacyTokens, rawFindings);
    const colors = collectDistinctColors(rawFindings);

    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const runDir = path.join(outputDir, `ui-run-${timestamp}`);
    await mkdir(runDir, { recursive: true });

    const themePath = path.join(runDir, "theme.json");
    const reportPath = path.join(runDir, "theme.report.json");
    const rawPath = path.join(runDir, "raw-findings.json");
    const cssPath = path.join(runDir, "theme.css");
    const legacyTokensPath = path.join(runDir, "legacy-tokens.json");

    await writeFile(themePath, JSON.stringify(theme, null, 2), "utf-8");
    await writeFile(reportPath, JSON.stringify(report satisfies ThemeReport, null, 2), "utf-8");
    await writeFile(rawPath, JSON.stringify(rawFindings, null, 2), "utf-8");
    await writeFile(cssPath, cssSnippet, "utf-8");
    await writeFile(legacyTokensPath, JSON.stringify(legacyTokens, null, 2), "utf-8");

    const entries = Object.values(report);
    const totalTokens = entries.length;
    const mappedTokens = entries.filter((entry) => !!entry.value).length;
    const highConfidence = entries.filter((entry) => entry.confidence >= 0.85).length;
    const mediumConfidence = entries.filter((entry) => entry.confidence >= 0.55 && entry.confidence < 0.85).length;

    res.json({
      ok: true,
      job: {
        url: parsedUrl.href,
        pages: extraction.pages.length,
        scheme,
        errors: extraction.errors,
        css: toPublicPath(cssPath),
      },
      outputs: {
        directory: path.relative(projectRoot, runDir),
        theme: toPublicPath(themePath),
        report: toPublicPath(reportPath),
        raw: toPublicPath(rawPath),
        css: toPublicPath(cssPath),
        legacyTokens: toPublicPath(legacyTokensPath),
      },
      stats: {
        rawFindings: rawFindings.length,
        totalTokens,
        mappedTokens,
        highConfidence,
        mediumConfidence,
        lowConfidence: totalTokens - highConfidence - mediumConfidence,
      },
      visuals: {
        colors,
      },
      snippets: {
        css: cssSnippet,
      },
      summary,
      rawFindings,
      colorDefaults,
    });
  } catch (error) {
    console.error("Extraction failed", error);
    res.status(500).json({
      ok: false,
      error: (error as Error).message ?? "Unexpected error during extraction",
    });
    schemaPromise = buildTokenSchema({ sassRoot });
  } finally {
    isBusy = false;
  }
});

app.post("/api/generate", async (req, res) => {
  const { rawFindings, selections } = req.body ?? {};
  if (!Array.isArray(rawFindings) || rawFindings.length === 0) {
    res.status(400).json({ ok: false, error: "rawFindings array required" });
    return;
  }
  try {
    const schema = await schemaPromise;
    const { theme, report } = mapFindingsToSchema(schema, rawFindings);
    const overrides: PaletteOverrides = {
      primary: selections?.primary ?? null,
      secondary: selections?.secondary ?? null,
      background: selections?.background ?? null,
      text: selections?.text ?? null,
    };
    const legacyTokens = buildLegacyTokens(rawFindings, overrides);
    const cssSnippet = buildCssFromLegacyCompiler(legacyTokens);
    const summary = buildThemeSummary(legacyTokens, rawFindings);
    res.json({
      ok: true,
      summary,
      snippets: { css: cssSnippet },
      legacyTokens,
      theme,
      report,
      colorDefaults,
    });
  } catch (error) {
    console.error("Generate API failed", error);
    res.status(500).json({ ok: false, error: (error as Error).message ?? "Unable to generate theme" });
  }
});

function toPublicPath(filePath: string): string {
  const relative = path.relative(projectRoot, filePath);
  return `/${relative.split(path.sep).join("/")}`;
}

function collectDistinctColors(findings: RawFinding[]): string[] {
  const colorRegex =
    /(#(?:[0-9a-fA-F]{3,8})(?![0-9a-fA-F]))|(rgba?\([^)]*\))|(hsla?\([^)]*\))|(\boklch\([^)]*\))/g;
  const candidates = new Set<string>();
  for (const finding of findings) {
    if (finding.category === "color") {
      const normalized = finding.value.trim().toLowerCase();
      if (normalized.length === 0) continue;
      candidates.add(normalized);
      continue;
    }
    let match: RegExpExecArray | null;
    while ((match = colorRegex.exec(finding.value)) !== null) {
      const token = match[0]?.toLowerCase();
      if (token) {
        candidates.add(token);
      }
    }
  }
  return Array.from(candidates).slice(0, 24);
}

function buildCssFromLegacyCompiler(legacyTokens: Record<string, unknown>): string {
  const result = compileTheme(legacyTokens);
  const overrides = result.css ?? "";
  const header = "/* CURATED BASE */";
  const footer = "/* GENERATED OVERRIDES */";
  return `${header}\n${curatedTemplate.trim()}\n\n${footer}\n${overrides.trim()}\n`;
}

function buildThemeSummary(tokens: Record<string, any>, findings: RawFinding[]) {
  const colors = tokens?.colors ?? {};
  const typography = tokens?.typography ?? {};
  return {
    curatedStructure: true,
    colors: {
      primary: colors.primary ?? null,
      secondary: colors.secondary ?? null,
      background: colors.bg ?? null,
      text: colors.text ?? null,
      muted: colors.muted ?? null,
    },
    typography: {
      fontFamily: typography.fontFamily ?? null,
    },
    logoColors: collectLogoPalette(findings),
  };
}

function collectLogoPalette(findings: RawFinding[]): string[] {
  const logos = findings.filter((finding) => finding.category === "color" && finding.normalizedName.startsWith("logo."));
  const unique = new Set<string>();
  for (const finding of logos) {
    const value = finding.value.trim().toLowerCase();
    if (!value) continue;
    if (!unique.has(value)) {
      unique.add(value);
    }
  }
  return Array.from(unique).slice(0, 6);
}

function parsePort(): number {
  const argIndex = process.argv.indexOf("--port");
  if (argIndex >= 0) {
    const value = Number.parseInt(process.argv[argIndex + 1] ?? "", 10);
    if (!Number.isNaN(value) && value > 0) {
      return value;
    }
  }
  const fromEnv = Number.parseInt(process.env.PORT ?? "", 10);
  if (!Number.isNaN(fromEnv) && fromEnv > 0) {
    return fromEnv;
  }
  return 5173;
}

const port = parsePort();

app.listen(port, () => {
  console.log(`Pulse Theme Generator v2 UI available at http://localhost:${port}`);
  console.log(`Outputs will be saved under ${outputDir}`);
});
