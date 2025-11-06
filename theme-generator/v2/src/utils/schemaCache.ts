import { readFile, writeFile, stat, mkdir } from "node:fs/promises";
import path from "node:path";
import { createHash } from "node:crypto";
import type { TokenSchema } from "../parser/tokenSchema.js";
import { buildTokenSchema } from "../parser/tokenSchema.js";
import type { SchemaOptions } from "../parser/tokenSchema.js";

interface CacheMetadata {
  timestamp: number;
  sassRoot: string;
  hash: string;
  schema: TokenSchema;
}

/**
 * Computes a hash of the SASS source files to detect changes
 */
async function computeSassHash(options: SchemaOptions): Promise<string> {
  const mapFile = options.mapFile ?? path.join(options.sassRoot, "_maps.scss");
  const variablesFile = options.variablesFile ?? path.join(options.sassRoot, "_variables.scss");
  const structureFile = options.structureFile ?? path.join(options.sassRoot, "_theme-structure.scss");

  const files = [mapFile, variablesFile, structureFile];
  const contents: string[] = [];

  for (const file of files) {
    try {
      const content = await readFile(file, "utf-8");
      const stats = await stat(file);
      contents.push(`${file}:${stats.mtimeMs}:${content.length}`);
    } catch {
      // If file doesn't exist, include that in hash
      contents.push(`${file}:missing`);
    }
  }

  return createHash("sha256").update(contents.join("|")).digest("hex");
}

/**
 * Gets the cache file path for a given SASS root
 */
function getCachePath(sassRoot: string): string {
  const hash = createHash("sha256").update(sassRoot).digest("hex").slice(0, 16);
  return path.join(process.cwd(), ".cache", `schema-${hash}.json`);
}

/**
 * Loads schema from cache if valid, otherwise returns null
 */
export async function loadCachedSchema(options: SchemaOptions): Promise<TokenSchema | null> {
  try {
    const cachePath = getCachePath(options.sassRoot);
    const cacheContent = await readFile(cachePath, "utf-8");
    const cache: CacheMetadata = JSON.parse(cacheContent);

    // Verify hash matches current SASS files
    const currentHash = await computeSassHash(options);
    if (cache.hash !== currentHash || cache.sassRoot !== options.sassRoot) {
      return null;
    }

    return cache.schema;
  } catch {
    return null;
  }
}

/**
 * Saves schema to cache
 */
export async function saveCachedSchema(options: SchemaOptions, schema: TokenSchema): Promise<void> {
  try {
    const cachePath = getCachePath(options.sassRoot);
    const cacheDir = path.dirname(cachePath);
    await mkdir(cacheDir, { recursive: true });

    const hash = await computeSassHash(options);
    const cache: CacheMetadata = {
      timestamp: Date.now(),
      sassRoot: options.sassRoot,
      hash,
      schema,
    };

    await writeFile(cachePath, JSON.stringify(cache, null, 2), "utf-8");
  } catch (error) {
    // Fail silently - caching is optional
    console.warn("Failed to cache schema:", (error as Error).message);
  }
}

/**
 * Builds token schema with caching support
 */
export async function buildTokenSchemaWithCache(options: SchemaOptions): Promise<TokenSchema> {
  // Try to load from cache first
  const cached = await loadCachedSchema(options);
  if (cached) {
    return cached;
  }

  // Build fresh schema
  const schema = await buildTokenSchema(options);

  // Save to cache (don't await - fire and forget)
  saveCachedSchema(options, schema).catch(() => {
    // Ignore cache save errors
  });

  return schema;
}

