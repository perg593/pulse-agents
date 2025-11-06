# Theme Generator Consolidation Plan

## Current State

### Active Theme Generators (Root Level)
1. **`theme-generator/`** - MVP 2.0 (JavaScript-based, analysis pipeline)
   - Status: Active, main generator
   - Features: 4 theme variations, Puppeteer analysis, JSON → CSS

2. **`pulse-theme-generator-v2/`** - TypeScript-based with web UI
   - Status: Active, web UI version
   - Features: Playwright extraction, SASS token mapping, web interface

### Legacy Theme Generators
3. **`legacy/theme-generators/v1-theme-mvp/`** - Version 1 MVP
   - Status: Legacy, deprecated
   - Contains: Original MVP implementation

4. **`legacy/theme-generators/v2-2021/`** - Version 2 from 2021
   - Status: Legacy, SASS framework
   - Contains: Historical SASS framework and client themes

### Other
5. **`preview/theme-generator/`** - Preview-specific UI
   - Status: Keep as-is (preview-specific)
   - Contains: Preview dashboard theme generator UI

6. **`legacy/theme-generator/`** - Deprecated file
   - Status: Contains deprecated HTML file

7. **`legacy/pulse-theme-generator-v2-output/`** - Output directory
   - Status: Legacy output

## Proposed Structure

```
theme-generator/
├── README.md                    # Main documentation (consolidated)
├── package.json                 # Root package.json (from current theme-generator/)
│
├── v1/                          # Current MVP 2.0 (rename from theme-generator/)
│   ├── main.js
│   ├── analyze-site.js
│   ├── theme-generator.js
│   ├── generate-theme-v2.mjs
│   └── ...
│
├── v2/                          # TypeScript web UI (move from pulse-theme-generator-v2/)
│   ├── src/
│   ├── public/
│   ├── scripts/
│   ├── tests/
│   ├── package.json
│   └── ...
│
└── legacy/
    ├── v1-mvp/                  # Move from legacy/theme-generators/v1-theme-mvp/
    └── v2-2021/                 # Move from legacy/theme-generators/v2-2021/
```

## Consolidation Steps

### Step 1: Rename current theme-generator/ to theme-generator/v1/
- Move all files from `theme-generator/` to `theme-generator/v1/`
- Keep package.json at root level (or consolidate)

### Step 2: Move pulse-theme-generator-v2/ to theme-generator/v2/
- Move entire directory preserving structure
- Update internal references if needed

### Step 3: Move legacy generators to theme-generator/legacy/
- Move `legacy/theme-generators/v1-theme-mvp/` → `theme-generator/legacy/v1-mvp/`
- Move `legacy/theme-generators/v2-2021/` → `theme-generator/legacy/v2-2021/`

### Step 4: Clean up
- Remove empty `legacy/theme-generators/` directory
- Handle `legacy/theme-generator/` deprecated file
- Keep `preview/theme-generator/` as-is (preview-specific)

## Files That Need Reference Updates

### Code References
- `config/paths.js` - May reference theme-generator paths
- `scripts/launch/*.sh` - Launch scripts
- `tests/integration/generators/extraction.test.ts` - Test references
- `package.json` - Script references
- Preview scripts that reference theme-generator

### Documentation References
- `docs/theme-generator/*.md` - All documentation
- `docs/deployment/output-directories.md`
- `README.md`
- `docs/planning/*.md` files

## Naming Convention

- Use `v1/`, `v2/` for active versions
- Use `legacy/v1-mvp/`, `legacy/v2-2021/` for historical versions
- Keep hyphenated naming consistent (`theme-generator/` not `theme_generator/`)

