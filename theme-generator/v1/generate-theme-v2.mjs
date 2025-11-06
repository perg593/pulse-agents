#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { compileTheme, deepMerge } = require('./src/theme-css.js');
// Script is in theme-generator/v1/, lib is at root level, so go up 2 levels
const { log, createLogger } = require('../../lib/logger.js');
const { ErrorFactory, ErrorHandler } = require('../../lib/errors.js');
const { FileValidator, ThemeValidator, ParameterValidator } = require('../../lib/validators.js');

// Create logger for theme generator v2
const logger = createLogger('ThemeGeneratorV2');

// Parameter validation schema
const ARG_SCHEMA = {
  inputFile: {
    type: 'string',
    required: true,
    minLength: 1,
    maxLength: 500
  },
  outputFile: {
    type: 'string',
    required: false,
    minLength: 1,
    maxLength: 500,
    default: 'out.css'
  }
};

const [, , inArg = 'theme.json', outArg = 'out.css'] = process.argv;

// Validate command line arguments
const args = [inArg, outArg];
const validation = ParameterValidator.validateArgs(args, ARG_SCHEMA);
if (!validation.valid) {
  logger.error('Invalid command line arguments', null, { errors: validation.errors });
  console.error('❌ Invalid arguments:');
  validation.errors.forEach(error => console.error(`  - ${error}`));
  console.log('');
  console.log('Usage: node generate-theme-v2.mjs <input.json> [output.css]');
  console.log('Example: node generate-theme-v2.mjs theme.json output.css');
  process.exit(1);
}

const { inputFile, outputFile } = validation.params;
const resolvedInputPath = path.resolve(process.cwd(), inputFile);

// Validate input file
if (!FileValidator.exists(resolvedInputPath)) {
  const error = ErrorFactory.fileOperation(`Theme file not found: ${resolvedInputPath}`, resolvedInputPath, 'read');
  logger.error('Theme file not found', error, { inputPath: resolvedInputPath });
  console.error(`Theme file not found: ${resolvedInputPath}`);
  process.exit(1);
}

if (!FileValidator.hasExtension(resolvedInputPath, ['.json'])) {
  const error = ErrorFactory.validation('Input file must be a JSON file', 'inputFile', inputFile);
  logger.error('Invalid input file extension', error, { inputPath: resolvedInputPath });
  console.error('❌ Input file must be a JSON file');
  process.exit(1);
}

let raw;
try {
  raw = JSON.parse(fs.readFileSync(resolvedInputPath, 'utf8'));
  logger.info('Theme file loaded successfully', { inputPath: resolvedInputPath, themeName: raw.name });
} catch (error) {
  const fileError = ErrorFactory.fileOperation(`Failed to parse theme file: ${error.message}`, resolvedInputPath, 'parse');
  logger.error('Theme file parse error', fileError, { inputPath: resolvedInputPath, parseError: error.message });
  console.error(`Failed to parse theme file: ${error.message}`);
  process.exit(1);
}

if (raw.extends) {
  const baseRef = raw.extends.endsWith('.json') ? raw.extends : `${raw.extends}.json`;
  const resolvedBase = path.resolve(path.dirname(resolvedInputPath), baseRef);
  if (!fs.existsSync(resolvedBase)) {
    logger.warn('Base theme file not found, continuing without merge', { basePath: resolvedBase, extends: raw.extends });
    console.warn(`warn: extends points to ${resolvedBase}, but file not found. Continuing without merge.`);
  } else {
    try {
      const base = JSON.parse(fs.readFileSync(resolvedBase, 'utf8'));
      raw = deepMerge(base, raw);
      logger.info('Base theme merged successfully', { basePath: resolvedBase, themeName: raw.name });
    } catch (error) {
      logger.warn('Failed to merge base theme, continuing with original', { basePath: resolvedBase, error: error.message });
      console.warn(`warn: Failed to merge base theme: ${error.message}`);
    }
  }
  delete raw.extends;
}

if (!raw.name) {
  raw.name = path.basename(resolvedInputPath, path.extname(resolvedInputPath));
  logger.info('Theme name derived from filename', { themeName: raw.name, filename: path.basename(resolvedInputPath) });
}

// Validate theme data against schema
const themeValidation = ThemeValidator.validate(raw);
if (!themeValidation.valid) {
  const error = ErrorFactory.validation(`Theme validation failed: ${themeValidation.errors.join('; ')}`, 'theme', raw);
  logger.error('Theme validation failed', error, { themeName: raw.name, errors: themeValidation.errors });
  console.error('❌ Theme validation failed:');
  themeValidation.errors.forEach(err => console.error(`  - ${err}`));
  process.exit(1);
}

// Log warnings if any
if (themeValidation.warnings.length > 0) {
  logger.warn('Theme validation warnings', { themeName: raw.name, warnings: themeValidation.warnings });
  themeValidation.warnings.forEach(warning => console.warn(`⚠️  ${warning}`));
}

const { css, warnings, errors } = compileTheme(raw);
warnings.forEach(msg => {
  logger.warn('Theme compilation warning', { warning: msg, themeName: raw.name });
  console.warn(`warn: ${msg}`);
});

if (errors.length) {
  const themeError = ErrorFactory.themeGeneration(`Theme compilation failed: ${errors.join('; ')}`, raw.name, errors);
  logger.error('Theme compilation failed', themeError, { themeName: raw.name, errors });
  errors.forEach(msg => console.error(`error: ${msg}`));
  process.exit(1);
}

const resolvedOutputPath = path.resolve(process.cwd(), outputFile);

// Validate output directory is writable
const outputDir = path.dirname(resolvedOutputPath);
if (!FileValidator.isWritable(outputDir)) {
  const error = ErrorFactory.fileOperation(`Output directory is not writable: ${outputDir}`, outputDir, 'write');
  logger.error('Output directory not writable', error, { outputDir });
  console.error(`❌ Output directory is not writable: ${outputDir}`);
  process.exit(1);
}

try {
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(resolvedOutputPath, css);
  logger.info('Theme CSS generated successfully', { 
    themeName: raw.name, 
    outputPath: resolvedOutputPath, 
    cssLength: css.length,
    warningCount: warnings.length 
  });
  console.log(`Wrote ${resolvedOutputPath}`);
} catch (error) {
  const fileError = ErrorFactory.fileOperation(`Failed to write CSS file: ${error.message}`, resolvedOutputPath, 'write');
  logger.error('CSS file write error', fileError, { outputPath: resolvedOutputPath, writeError: error.message });
  console.error(`Failed to write CSS file: ${error.message}`);
  process.exit(1);
}
