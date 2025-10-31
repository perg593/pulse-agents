#!/usr/bin/env tsx
import path from "node:path";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { buildTokenSchema } from "../src/parser/tokenSchema.js";
import { mapFindingsToSchema } from "../src/mapper/mapToSchema.js";
import { RawFinding, ThemeReport } from "../src/types.js";
import { getSassRoot, getOutputDir } from "../src/utils/config.js";

interface CliOptions {
  rawPath: string;
  outDir: string;
  sassRoot: string;
}

function printUsage() {
  console.log(`Pulse Theme Mapper

Usage:
  tsx scripts/map-to-pulse.ts --raw ./output/raw-findings.json [--out ./output] [--sass ./Old-Pulse-Themes-Framework-2025/01-css-pulse]
`);
}

function parseArgs(argv: string[]): CliOptions {
  const args = [...argv];
  const options: Partial<CliOptions> = {};

  while (args.length > 0) {
    const arg = args.shift();
    if (!arg) break;
    switch (arg) {
      case "--raw":
        options.rawPath = args.shift() ?? "";
        break;
      case "--out":
        options.outDir = args.shift() ?? "";
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

  if (!options.rawPath) {
    printUsage();
    throw new Error("Missing --raw argument");
  }

  return {
    rawPath: path.resolve(options.rawPath),
    outDir: options.outDir ? path.resolve(options.outDir) : getOutputDir(),
    sassRoot: options.sassRoot ? path.resolve(options.sassRoot) : getSassRoot(),
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  await mkdir(args.outDir, { recursive: true });

  const rawContent = await readFile(args.rawPath, "utf-8");
  const rawFindings = JSON.parse(rawContent) as RawFinding[];

  const schema = await buildTokenSchema({ sassRoot: args.sassRoot });
  const { theme, report } = mapFindingsToSchema(schema, rawFindings);

  const themePath = path.join(args.outDir, "theme.json");
  const reportPath = path.join(args.outDir, "theme.report.json");
  await writeFile(themePath, JSON.stringify(theme, null, 2), "utf-8");
  await writeFile(reportPath, JSON.stringify(report satisfies ThemeReport, null, 2), "utf-8");

  console.log(`Wrote theme output to:
  - ${themePath}
  - ${reportPath}
`);
}

main().catch((error) => {
  console.error("Mapping failed:", error);
  process.exit(1);
});
