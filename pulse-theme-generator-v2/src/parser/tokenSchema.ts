import { readFile } from "node:fs/promises";
import path from "node:path";
import { parseSassFile, SassVariable, SassMap } from "./sassParser.js";
import { ThemeJson } from "../types.js";

export interface TokenDescriptor {
  id: string;
  group: string;
  originalGroup: string;
  key: string;
  originalKey: string;
  variable: string | null;
  file: string;
  line: number;
  column: number;
}

export interface TokenGroup {
  name: string;
  originalName: string;
  file: string;
  line: number;
  column: number;
  tokens: TokenDescriptor[];
}

export interface BuilderReference {
  name: string;
  line: number;
  column: number;
}

export interface TokenSchema {
  groups: TokenGroup[];
  variables: Record<string, SassVariable>;
  builders: BuilderReference[];
  tokenIndex: Record<string, TokenDescriptor>;
}

export interface SchemaOptions {
  sassRoot: string;
  mapFile?: string;
  variablesFile?: string;
  structureFile?: string;
}

function toCamelCase(input: string): string {
  return input
    .split(/[_\-\s]+/)
    .filter(Boolean)
    .map((segment, index) => {
      if (index === 0) {
        return segment.toLowerCase();
      }
      return segment.charAt(0).toUpperCase() + segment.slice(1).toLowerCase();
    })
    .join("");
}

function normalizeMapName(map: SassMap): TokenGroup {
  const name = toCamelCase(map.name);
  return {
    name,
    originalName: map.name,
    file: map.file,
    line: map.line,
    column: map.column,
    tokens: [],
  };
}

function normalizeKeyName(key: string): string {
  return toCamelCase(key);
}

async function extractBuilders(structureFile: string): Promise<BuilderReference[]> {
  const absolute = path.resolve(structureFile);
  const content = await readFile(absolute, "utf-8");
  const builders: BuilderReference[] = [];
  const lines = content.split(/\r?\n/);
  for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    const line = lines[lineIndex];
    const regex = /builder\(\s*["']([^"']+)["']\s*\)/g;
    let match: RegExpExecArray | null;
    while ((match = regex.exec(line)) !== null) {
      builders.push({
        name: match[1],
        line: lineIndex + 1,
        column: (match.index ?? 0) + 1,
      });
    }
  }
  return builders;
}

function buildGroupDescriptors(maps: SassMap[], variables: Record<string, SassVariable>): TokenGroup[] {
  return maps.map((map) => {
    const group = normalizeMapName(map);
    const tokens: TokenDescriptor[] = map.entries.map((entry) => {
      const normalizedKey = normalizeKeyName(entry.key);
      const variableName = entry.value.startsWith("$") ? entry.value.slice(1) : null;
      const resolvedVariable = variableName ? variables[variableName] : undefined;
      return {
        id: `${group.name}.${normalizedKey}`,
        group: group.name,
        originalGroup: group.originalName,
        key: normalizedKey,
        originalKey: entry.key,
        variable: variableName,
        file: resolvedVariable?.file ?? map.file,
        line: resolvedVariable?.line ?? entry.line,
        column: resolvedVariable?.column ?? entry.column,
      };
    });
    group.tokens = tokens;
    return group;
  });
}

/**
 * Builds a token schema by parsing SASS files and extracting variable definitions,
 * map structures, and builder references.
 *
 * @param options - Schema building options
 * @param options.sassRoot - Root directory containing SASS source files
 * @param options.mapFile - Path to _maps.scss file (defaults to sassRoot/_maps.scss)
 * @param options.variablesFile - Path to _variables.scss file (defaults to sassRoot/_variables.scss)
 * @param options.structureFile - Path to _theme-structure.scss file (defaults to sassRoot/_theme-structure.scss)
 * @returns Promise resolving to the complete token schema with groups, variables, builders, and index
 *
 * @example
 * ```typescript
 * const schema = await buildTokenSchema({
 *   sassRoot: "./sass"
 * });
 * console.log(`Found ${schema.groups.length} token groups`);
 * ```
 */
export async function buildTokenSchema(options: SchemaOptions): Promise<TokenSchema> {
  const mapFile = options.mapFile ?? path.join(options.sassRoot, "_maps.scss");
  const variablesFile = options.variablesFile ?? path.join(options.sassRoot, "_variables.scss");
  const structureFile = options.structureFile ?? path.join(options.sassRoot, "_theme-structure.scss");

  const [mapParse, variableParse, builders] = await Promise.all([
    parseSassFile(mapFile),
    parseSassFile(variablesFile),
    extractBuilders(structureFile),
  ]);

  const variables = Object.fromEntries(variableParse.variables.map((variable) => [variable.name, variable]));
  const groups = buildGroupDescriptors(mapParse.maps, variables);
  const tokenIndex: Record<string, TokenDescriptor> = {};
  for (const group of groups) {
    for (const token of group.tokens) {
      tokenIndex[token.id] = token;
    }
  }

  return {
    groups,
    variables,
    builders,
    tokenIndex,
  };
}

/**
 * Creates an empty theme object matching the schema structure.
 * All token values are initialized to null.
 *
 * @param schema - Token schema to create theme from
 * @returns Empty theme object with structure matching the schema
 */
export function schemaToEmptyTheme(schema: TokenSchema): ThemeJson {
  const theme: ThemeJson = {};
  for (const group of schema.groups) {
    const bucket: Record<string, unknown> = {};
    for (const token of group.tokens) {
      bucket[token.key] = null;
    }
    theme[group.name] = bucket;
  }
  return theme;
}

/**
 * Extracts all token IDs from the schema.
 *
 * @param schema - Token schema to extract IDs from
 * @returns Array of all token IDs in the format "group.key"
 */
export function schemaTokenIds(schema: TokenSchema): string[] {
  return schema.groups.flatMap((group) => group.tokens.map((token) => token.id));
}
