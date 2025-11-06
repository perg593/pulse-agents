import path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Configuration utilities for Pulse Theme Generator v2
 * Handles path resolution and environment variable configuration
 */

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, "../..");

/**
 * Gets the SASS root directory from environment variable or default path
 */
export function getSassRoot(): string {
  const envPath = process.env.PULSE_SASS_ROOT;
  if (envPath) {
    return path.resolve(envPath);
  }
  // Default relative to project root
  return path.resolve(projectRoot, "../sass-framework/01-css-pulse");
}

/**
 * Gets the output directory from environment variable or default path
 */
export function getOutputDir(): string {
  const envPath = process.env.PULSE_OUTPUT_DIR;
  if (envPath) {
    return path.resolve(envPath);
  }
  return path.resolve(projectRoot, "output");
}

/**
 * Gets the project root directory
 */
export function getProjectRoot(): string {
  return projectRoot;
}

/**
 * Validates that a path is within the project root or a specified allowed directory
 * Prevents directory traversal attacks
 */
export function validatePath(filePath: string, allowedRoot?: string): boolean {
  const resolved = path.resolve(filePath);
  const root = allowedRoot ? path.resolve(allowedRoot) : projectRoot;
  return resolved.startsWith(root + path.sep) || resolved === root;
}

/**
 * Sanitizes a filename to prevent directory traversal
 */
export function sanitizeFilename(filename: string): string {
  return path.basename(filename).replace(/[^a-zA-Z0-9._-]/g, "_");
}

