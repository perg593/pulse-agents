# API Documentation

## Environment Variables

The following environment variables can be used to configure paths:

- `PULSE_SASS_ROOT` - Path to SASS source files (default: `../sass-framework/01-css-pulse`)
- `PULSE_OUTPUT_DIR` - Path to output directory (default: `./output`)

## API Endpoints

### GET `/api/status`

Returns the current status of the schema and extractor.

**Response:**
```json
{
  "ok": true,
  "tokens": 150,
  "groups": 12,
  "busy": false,
  "sassRoot": "/path/to/sass",
  "colorDefaults": []
}
```

### POST `/api/extract`

Extracts theme data from a target URL.

**Request Body:**
```json
{
  "url": "https://example.com",
  "pages": 3,
  "scheme": "light"
}
```

**Response:**
```json
{
  "ok": true,
  "job": {
    "url": "https://example.com",
    "pages": 3,
    "scheme": "light",
    "errors": [],
    "css": "/output/ui-run-.../theme.css"
  },
  "outputs": {
    "directory": "output/ui-run-...",
    "theme": "/output/ui-run-.../theme.json",
    "report": "/output/ui-run-.../theme.report.json",
    "raw": "/output/ui-run-.../raw-findings.json",
    "css": "/output/ui-run-.../theme.css",
    "legacyTokens": "/output/ui-run-.../legacy-tokens.json"
  },
  "stats": {
    "rawFindings": 45,
    "totalTokens": 150,
    "mappedTokens": 120,
    "highConfidence": 85,
    "mediumConfidence": 25,
    "lowConfidence": 10
  },
  "visuals": {
    "colors": ["#ff0000", "#00ff00", ...]
  },
  "snippets": {
    "css": "/* CURATED BASE */\n..."
  },
  "summary": {
    "curatedStructure": true,
    "colors": {
      "primary": "#ff0000",
      "secondary": "#00ff00",
      "background": "#ffffff",
      "text": "#000000",
      "muted": "#666666"
    },
    "typography": {
      "fontFamily": "Arial, sans-serif"
    },
    "logoColors": ["#ff0000", "#00ff00"]
  }
}
```

### POST `/api/generate`

Regenerates theme CSS from raw findings with optional palette overrides.

**Request Body:**
```json
{
  "rawFindings": [...],
  "selections": {
    "primary": "#ff0000",
    "secondary": "#00ff00",
    "background": "#ffffff",
    "text": "#000000"
  }
}
```

**Response:**
```json
{
  "ok": true,
  "summary": {...},
  "snippets": {
    "css": "/* CURATED BASE */\n..."
  },
  "legacyTokens": {...},
  "theme": {...},
  "report": {...},
  "colorDefaults": []
}
```

## CLI Commands

### Extract Theme

```bash
npx tsx scripts/extract-theme.ts --url https://example.com [options]
```

**Options:**
- `--url <url>` - Target website URL (required)
- `--out <dir>` - Output directory (default: `./output`)
- `--pages <n>` - Maximum pages to crawl (default: 3)
- `--scheme <light|dark>` - Color scheme preference (default: light)
- `--sass <path>` - Path to SASS source files

### Map to Pulse

```bash
npx tsx scripts/map-to-pulse.ts --raw <raw-findings.json> [options]
```

**Options:**
- `--raw <path>` - Path to raw findings JSON file (required)
- `--out <dir>` - Output directory (default: `./output`)
- `--sass <path>` - Path to SASS source files

## Core Functions

### `extractSite(options)`

Extracts theme data from a website using Playwright.

**Parameters:**
- `options.url` - Target website URL
- `options.maxPages` - Maximum pages to crawl
- `options.scheme` - Color scheme preference
- `options.timeoutMs` - Navigation timeout

**Returns:** Promise resolving to `SiteExtractionResult`

### `mapFindingsToSchema(schema, findings, options)`

Maps raw findings to the Pulse token schema.

**Parameters:**
- `schema` - Token schema object
- `findings` - Array of raw findings
- `options.preferredSelectors` - Optional selector priority list

**Returns:** Object with `theme`, `report`, and `unmatched` tokens

### `buildLegacyTokens(rawFindings, overrides)`

Builds legacy Pulse widget tokens from raw findings.

**Parameters:**
- `rawFindings` - Array of raw findings
- `overrides` - Optional palette overrides

**Returns:** Legacy token object

