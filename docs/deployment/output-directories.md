# Output Directory Patterns

This document describes the output directory patterns used across different generators and build processes in the Pulse Widgets codebase.

## Theme Generator Outputs

### Active Generator (`theme-generator/`)

**Output Location:** `theme-generator/output/`

**Structure:**
```
theme-generator/output/
└── client-themes/
    ├── index.json          # Client/theme index
    └── [client-name]/
        ├── brand-faithful.css
        ├── high-contrast.css
        ├── modern.css
        ├── minimalist.css
        └── themes.json
```

### Legacy Generators (`legacy/theme-generators/`)

**Legacy Output Locations:**
- `legacy/output/client-themes/` - Output from legacy theme-mvp generator
- `legacy/pulse-theme-generator-v2-output/` - Output from pulse-theme-generator-v2 (if archived)

**Note:** Legacy generators are kept for historical reference. Use the active `theme-generator/` for new development.

## Preview Build Outputs

### Preview Dist (`preview/dist/`)

**Location:** `preview/dist/`

**Contents:**
- Generated CSS files
- Compiled theme outputs
- Manifest files

**Build Command:** `npm run preview:build` (from `theme-generator/`)

## Pulse Theme Generator v2 Outputs

**Active Generator:** `pulse-theme-generator-v2/output/`

**Structure:**
```
pulse-theme-generator-v2/output/
├── ui-run-[timestamp]/
│   ├── theme.json
│   ├── theme.report.json
│   ├── raw-findings.json
│   ├── theme.css
│   └── legacy-tokens.json
```

**Note:** This generator runs a web UI and produces timestamped output directories.

## Output Directory Best Practices

1. **Use Active Generators:** Always use the active `theme-generator/` for new theme generation
2. **Version Control:** Output directories are typically gitignored - only commit generated assets that are needed for deployment
3. **Cleanup:** Periodically clean old output directories to save disk space
4. **Documentation:** Update this document when adding new output patterns

## Build Artifacts

Build artifacts are excluded from deployment via `.cfignore`:
- `node_modules/`
- `output/` directories
- Build temporary files

