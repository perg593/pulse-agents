#!/usr/bin/env -S tsx
import express from "express";
import path from "node:path";
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
import { getSassRoot, getOutputDir, getProjectRoot } from "../src/utils/config.js";
import { buildTokenSchemaWithCache } from "../src/utils/schemaCache.js";

const app = express();
app.use(express.json({ limit: "2mb" }));

const projectRoot = getProjectRoot();
const publicDir = path.join(projectRoot, "public");
const outputDir = getOutputDir();
const sassRoot = getSassRoot();
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

let schemaPromise = buildTokenSchemaWithCache({ sassRoot });
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
    schemaPromise = buildTokenSchemaWithCache({ sassRoot });
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

interface ColorCategory {
  category: string;
  colors: string[];
}

function categorizeColor(finding: RawFinding): string | null {
  const normalizedName = finding.normalizedName.toLowerCase();
  const value = finding.value.trim().toLowerCase();
  
  if (value.length === 0) return null;
  
  // Check computed selector from evidence (priority 1)
  for (const source of finding.sources) {
    if (source.type === "computed") {
      const selector = source.selector.toLowerCase();
      const property = source.property.toLowerCase();
      
      // Headings (h1, h2, h3 color properties)
      if ((selector.includes("h1") || selector.includes("h2") || selector.includes("h3")) && property === "color") {
        return "Headings";
      }
      
      // Buttons (button/.btn background-color and color)
      if ((selector.includes("button") || selector.includes(".btn")) && (property === "background-color" || property === "color")) {
        return property === "background-color" ? "Button Backgrounds" : "Button Text";
      }
      
      // Links (a color properties)
      if (selector.includes("a[") && property === "color") {
        return "Links";
      }
      
      // Body text
      if (selector.includes("body[") && property === "color") {
        return "Text";
      }
      
      // Cards/Surfaces
      if (selector.includes(".card") && (property === "background-color" || property === "background")) {
        return "Cards/Surfaces";
      }
    }
    
    // Check property type for CSS declarations
    if (source.type === "css-prop" || source.type === "css-var") {
      const property = source.property.toLowerCase();
      const selector = source.selector.toLowerCase();
      
      // Headings from CSS rules
      if ((selector.includes("h1") || selector.includes("h2") || selector.includes("h3")) && property === "color") {
        return "Headings";
      }
      
      // Buttons from CSS rules
      if ((selector.includes("button") || selector.includes(".btn")) && (property === "background-color" || property === "color")) {
        return property === "background-color" ? "Button Backgrounds" : "Button Text";
      }
      
      // Links from CSS rules
      if (selector.includes("a") && property === "color") {
        return "Links";
      }
      
      // Body/global backgrounds
      if ((selector.includes("body") || selector.includes(":root") || selector.includes("html")) && 
          (property === "background-color" || property === "background")) {
        return "Backgrounds";
      }
      
      // Body text
      if ((selector.includes("body") || selector.includes(":root") || selector.includes("html")) && property === "color") {
        return "Text";
      }
      
      // Cards/Surfaces
      if ((selector.includes(".card") || selector.includes(".surface") || selector.includes(".panel")) && 
          (property === "background-color" || property === "background")) {
        return "Cards/Surfaces";
      }
    }
  }
  
  // Check normalized name patterns (priority 2)
  if (normalizedName.includes("h1") || normalizedName.includes("h2") || normalizedName.includes("h3") || normalizedName.includes("heading")) {
    if (normalizedName.includes("color")) {
      return "Headings";
    }
  }
  
  if (normalizedName.includes("button") || normalizedName.includes("btn")) {
    if (normalizedName.includes("background") || normalizedName.includes("bg")) {
      return "Button Backgrounds";
    }
    if (normalizedName.includes("color")) {
      return "Button Text";
    }
  }
  
  if (normalizedName.includes("link") || normalizedName.includes("a.")) {
    if (normalizedName.includes("color")) {
      return "Links";
    }
  }
  
  if (normalizedName.includes("background") || normalizedName.includes("bg")) {
    if (normalizedName.includes("body") || normalizedName.includes("root") || normalizedName.includes("html")) {
      return "Backgrounds";
    }
    if (normalizedName.includes("card") || normalizedName.includes("surface") || normalizedName.includes("panel")) {
      return "Cards/Surfaces";
    }
    return "Backgrounds";
  }
  
  if (normalizedName.includes("body") || normalizedName.includes("root") || normalizedName.includes("html")) {
    if (normalizedName.includes("color")) {
      return "Text";
    }
  }
  
  // Check property type (priority 3)
  for (const source of finding.sources) {
    if (source.type === "computed" || source.type === "css-prop") {
      const property = source.property.toLowerCase();
      if (property === "background-color" || property === "background") {
        return "Backgrounds";
      }
      if (property === "color") {
        return "Text";
      }
    }
  }
  
  return null;
}

function collectDistinctColors(findings: RawFinding[]): ColorCategory[] {
  const colorRegex =
    /(#(?:[0-9a-fA-F]{3,8})(?![0-9a-fA-F]))|(rgba?\([^)]*\))|(hsla?\([^)]*\))|(\boklch\([^)]*\))/g;
  
  const categoryMap = new Map<string, Set<string>>();
  
  // Initialize category order
  const categoryOrder = [
    "Headings",
    "Button Backgrounds",
    "Button Text",
    "Links",
    "Backgrounds",
    "Text",
    "Cards/Surfaces",
    "Other"
  ];
  
  for (const category of categoryOrder) {
    categoryMap.set(category, new Set<string>());
  }
  
  for (const finding of findings) {
    if (finding.category === "color") {
      const normalized = finding.value.trim().toLowerCase();
      if (normalized.length === 0) continue;
      
      const category = categorizeColor(finding) || "Other";
      const categorySet = categoryMap.get(category) || categoryMap.get("Other")!;
      categorySet.add(normalized);
      continue;
    }
    
    // Extract colors from non-color findings (e.g., shadow values)
    // Use matchAll to avoid regex state issues
    const matches = finding.value.matchAll(colorRegex);
    for (const match of matches) {
      const token = match[0]?.toLowerCase();
      if (token) {
        const category = categorizeColor(finding) || "Other";
        const categorySet = categoryMap.get(category) || categoryMap.get("Other")!;
        categorySet.add(token);
      }
    }
  }
  
  // Convert to array format and filter empty categories
  const result: ColorCategory[] = [];
  for (const category of categoryOrder) {
    const colors = Array.from(categoryMap.get(category)!);
    if (colors.length > 0) {
      result.push({
        category,
        colors: colors.slice(0, 12), // Limit colors per category
      });
    }
  }
  
  return result;
}

function buildCssFromLegacyCompiler(legacyTokens: Record<string, unknown>): string {
  const result = compileTheme(legacyTokens);
  const overrides = result.css ?? "";
  const header = "/* CURATED BASE */";
  const footer = "/* GENERATED OVERRIDES */";
  return `${header}\n${curatedTemplate.trim()}\n\n${footer}\n${overrides.trim()}\n`;
}

interface ThemeSummary {
  curatedStructure: boolean;
  colors: {
    primary: string | null;
    secondary: string | null;
    background: string | null;
    text: string | null;
    muted: string | null;
  };
  typography: {
    fontFamily: string | null;
  };
  logoColors: string[];
}

function buildThemeSummary(tokens: Record<string, unknown>, findings: RawFinding[]): ThemeSummary {
  const colors = (tokens?.colors as Record<string, unknown>) ?? {};
  const typography = (tokens?.typography as Record<string, unknown>) ?? {};
  return {
    curatedStructure: true,
    colors: {
      primary: (colors.primary as string | undefined) ?? null,
      secondary: (colors.secondary as string | undefined) ?? null,
      background: (colors.bg as string | undefined) ?? null,
      text: (colors.text as string | undefined) ?? null,
      muted: (colors.muted as string | undefined) ?? null,
    },
    typography: {
      fontFamily: (typography.fontFamily as string | undefined) ?? null,
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

