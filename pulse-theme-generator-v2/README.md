# Pulse Theme Generator v2

Automated pipeline that inspects a target site, learns its styling system, and maps it onto Pulse's theme token schema derived from our SASS source.

## Quick Start

1. Install dependencies (from this directory):
   ```bash
   npm install
   ```
2. Launch the web UI:
   ```bash
   npm run dev
   ```
   Open <http://localhost:5173>, enter the client URL, choose scheme/pages, and download the generated `theme.json` / `theme.report.json` artifacts.
   The UI also renders a ready-to-paste CSS snippet for the Pulse Insights admin, plus a quick summary of primary/secondary/background/text colors and detected font stack.
   After extraction you can mix and match detected colors (including logo tones) and re-generate the CSS in-place.
3. Prefer the CLI? Extract theme data from a site (homepage + up to 3 deep links by default):
   ```bash
   npx tsx scripts/extract-theme.ts --url https://example.com
   ```
   Outputs land in `./output`:
   - `theme.json` – canonical Pulse theme object.
   - `theme.report.json` – evidence, confidence scoring, derived notes.
   - `raw-findings.json` – intermediate findings (inputs for the mapper).
4. Re-run the mapping against saved findings:
   ```bash
   npx tsx scripts/map-to-pulse.ts --raw ./output/raw-findings.json
   ```

Use `--pages N` to change crawl depth, `--scheme dark` to force a dark-mode render, and `--sass <path>` to point at alternate Pulse SASS sources.

## Browser Snippet

To run the extractor inside an already-loaded page, paste the contents of `scripts/extract-snippet.js` into the browser console. Then call:

```js
PulseThemeExtractor.collect();
```

Copy the returned JSON into `raw-findings.json` and run the mapper.

## Architecture

- **Token schema**: `src/parser/` parses `_maps.scss`, `_variables.scss`, and `_theme-structure.scss` to build a live schema (no hard-coded token names).
- **Site extraction**: `src/extractor/` spins up Playwright, aggregates global/component CSS variables, base props, computed fallbacks, and theme toggles.
- **Findings synthesis**: `src/mapper/rawFindings.ts` normalises evidence, applies selector priority, and derives missing palettes (OKLCH tonal steps).
- **Legacy token bridge**: `src/mapper/legacyTokenBuilder.ts` converts raw findings into the legacy Pulse widget token schema (colors, typography).
- **CSS compilation**: `src/legacy/themeCompiler.ts` wraps the v1 theme compiler to emit fully scoped widget CSS with focus/legacy layers.
- **Mapping & scoring**: `src/mapper/mapToSchema.ts` resolves findings into schema tokens with confidence rules + provenance trail.
- **Logo analysis**: Playwright collector samples logo images/SVG fills to propose brand colors even when site chrome stays neutral.

## Outputs

- `theme.json` – canonical Pulse theme object derived from SASS token schema.
- `theme.report.json` – token evidence, confidence scores, provenance, and fallback notes.
- `raw-findings.json` – raw CSS/computed samples captured from the target site.
- `theme.css` – full widget CSS compiled via the legacy Pulse compiler (ready to paste into Pulse Insights).
- `legacy-tokens.json` – normalized Pulse widget tokens used for CSS compilation.

## Tests

Run integration tests (requires network + Playwright browser binaries):

```bash
npm test
```

Tests target:
1. A CSS variable–heavy site (e.g. `https://web.dev`).
2. A legacy/static CSS site (e.g. `https://example.com`).

Set `SKIP_PUBLIC_SITE_TESTS=1` to skip networked cases.

## Known Limitations

- Cross-origin stylesheets that disallow inspection are skipped (noted in `theme.report.json`).
- Selector matching is best-effort; highly dynamic frameworks may need manual follow-up.
- Deriving palettes from a single brand color is heuristic and may require human tuning.
- Logo color sampling depends on CORS; locked-down assets may be ignored or produce incomplete palettes.
- Playwright must be installed (`npx playwright install chromium`) before first run.

## Next Steps

- Add WCAG contrast annotations to the report.
- Expand component selector list with product-specific overrides.
- Persist screenshots alongside extracted findings for visual QA.
