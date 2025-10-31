#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import url from 'url';
import childProcess from 'child_process';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..', '..');
const generateThemePath = path.join(rootDir, 'theme-generator', 'generate-theme-v2.mjs');
const distDir = path.join(rootDir, 'preview', 'dist');

const [jsonPath, outPathArg] = process.argv.slice(2);
if (!jsonPath) {
  console.error('Usage: apply-preview-theme.js <theme.json> [out.css]');
  process.exit(1);
}

const inputPath = path.resolve(process.cwd(), jsonPath);
if (!fs.existsSync(inputPath)) {
  console.error(`Theme JSON not found: ${inputPath}`);
  process.exit(1);
}

const outputPath = outPathArg
  ? path.resolve(process.cwd(), outPathArg)
  : path.join(distDir, `${path.basename(jsonPath, '.json')}.css`);

fs.mkdirSync(path.dirname(outputPath), { recursive: true });

childProcess.execSync(`node ${generateThemePath} ${inputPath} ${outputPath}`, {
  stdio: 'inherit'
});

console.log(`Generated ${outputPath}`);
