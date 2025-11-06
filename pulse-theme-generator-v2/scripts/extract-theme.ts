#!/usr/bin/env tsx
import path from "node:path";
import { mkdir, writeFile } from "node:fs/promises";
import { buildTokenSchema } from "../src/parser/tokenSchema.js";
import { extractSite, DEFAULT_GLOBAL_SELECTORS } from "../src/extractor/extractSite.js";
import { buildRawFindings } from "../src/mapper/rawFindings.js";
import { mapFindingsToSchema } from "../src/mapper/mapToSchema.js";
import { ThemeReport } from "../src/types.js";
import { getSassRoot, getOutputDir } from "../src/utils/config.js";

interface CliOptions {
  url: string;
  outDir: string;
  maxPages: number;
  scheme: "light" | "dark";
  sassRoot: string;
}

function printUsage() {
  console.log(`Pulse Theme Generator v2

Usage:
  tsx scripts/extract-theme.ts --url https://example.com [--out ./output] [--pages 3] [--scheme light|dark] [--sass ./sass-framework/01-css-pulse]
`);
}

function parseArgs(argv: string[]): CliOptions {
  const args = [...argv];
  const options: Partial<CliOptions> = {};
  while (args.length > 0) {
    const arg = args.shift();
    if (!arg) break;
    switch (arg) {
      case "--url":
        options.url = args.shift() ?? "";
        break;
      case "--out":
        options.outDir = args.shift() ?? "";
        break;
      case "--pages":
        options.maxPages = Number.parseInt(args.shift() ?? "1", 10);
        break;
      case "--scheme":
        options.scheme = (args.shift() ?? "light") as CliOptions["scheme"];
        break;
      case "--sass":
        options.sassRoot = args.shift() ?? "";
        break;
      case "--help":
      case "-h":
        printUsage();
        process.exit(0);
        break;
      default:
        console.warn(`Unknown argument: ${arg}`);
        break;
    }
  }

  if (!options.url) {
    printUsage();
    throw new Error("Missing --url argument");
  }

  return {
    url: options.url,
    outDir: options.outDir ? path.resolve(options.outDir) : getOutputDir(),
    maxPages: options.maxPages ?? 3,
    scheme: options.scheme ?? "light",
    sassRoot: options.sassRoot ? path.resolve(options.sassRoot) : getSassRoot(),
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  await mkdir(args.outDir, { recursive: true });

  console.log(`Building Pulse token schema from ${args.sassRoot}`);
  const schema = await buildTokenSchema({ sassRoot: args.sassRoot });
  console.log(`Discovered ${schema.groups.length} token groups and ${schemaTokenCount(schema)} tokens`);

  console.log(`Extracting styles from ${args.url} (${args.maxPages} page(s), scheme=${args.scheme})`);
  const siteResult = await extractSite({ url: args.url, maxPages: args.maxPages, scheme: args.scheme });
  if (siteResult.errors.length > 0) {
    console.warn("Encountered extraction errors:");
    siteResult.errors.forEach((error) => console.warn(`  - ${error}`));
  }

  console.log(`Collected ${siteResult.pages.length} page sample(s)`);
  const rawFindings = buildRawFindings(siteResult.pages, {
    selectorPriority: DEFAULT_GLOBAL_SELECTORS,
  });
  console.log(`Assembled ${rawFindings.length} raw findings`);

  const { theme, report } = mapFindingsToSchema(schema, rawFindings);
  const themePath = path.join(args.outDir, "theme.json");
  const reportPath = path.join(args.outDir, "theme.report.json");
  const rawPath = path.join(args.outDir, "raw-findings.json");

  await writeFile(themePath, JSON.stringify(theme, null, 2), "utf-8");
  await writeFile(reportPath, JSON.stringify(report satisfies ThemeReport, null, 2), "utf-8");
  await writeFile(rawPath, JSON.stringify(rawFindings, null, 2), "utf-8");

  console.log(`\nOutputs:
  - ${themePath}
  - ${reportPath}
  - ${rawPath}
`);
}

function schemaTokenCount(schema: Awaited<ReturnType<typeof buildTokenSchema>>): number {
  return schema.groups.reduce((count, group) => count + group.tokens.length, 0);
}

main().catch((error) => {
  console.error("Extraction failed:", error);
  process.exit(1);
});
