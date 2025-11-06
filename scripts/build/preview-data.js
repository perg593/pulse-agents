#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '..', '..');

const CLIENT_THEMES_PATH = path.join(rootDir, 'theme-generator', 'output', 'client-themes', 'index.json');
const MANIFEST_OUT = path.join(rootDir, 'theme-generator', 'output', 'preview-manifest.json');
const DEFAULT_THEME_JSON = path.join(rootDir, 'preview', 'themes', 'default.json');
const DIST_DIR = path.join(rootDir, 'preview', 'dist');
const DEFAULT_THEME_OUT = path.join(DIST_DIR, 'default.css');

const WIDGET_BASE = '/preview/widgets';

const widgetFamilies = [
  {
    key: 'docked',
    label: 'Docked',
    desktopFolder: 'docked_widget',
    mobileFolder: 'docked_widget_mobile'
  },
  {
    key: 'overlay',
    label: 'Overlay',
    desktopFolder: 'overlay',
    mobileFolder: 'overlay_mobile'
  },
  {
    key: 'topbar',
    label: 'Top Bar',
    desktopFolder: 'top_bar',
    mobileFolder: 'top_bar_mobile'
  },
  {
    key: 'inline',
    label: 'Inline',
    desktopFolder: 'inline',
    mobileFolder: 'inline_mobile'
  },
  {
    key: 'bottombar',
    label: 'Bottom Bar',
    desktopFolder: 'bottom_bar',
    mobileFolder: 'bottom_bar_mobile'
  }
];

function buildWidgetEntries() {
  const widgetsDir = path.join(rootDir, 'preview', 'widgets');
  const entries = [];

  const makeEntry = (idSuffix, labelSuffix, folder) => {
    if (!folder) return;
    const filesystemPath = path.join(widgetsDir, folder, 'single_choice_standard_buttons.html');
    if (!fs.existsSync(filesystemPath)) return;
    entries.push({
      id: idSuffix,
      label: labelSuffix,
      path: `${WIDGET_BASE}/${folder}/single_choice_standard_buttons.html`
    });
  };

  widgetFamilies.forEach(family => {
    makeEntry(`${family.key}-desktop`, `${family.label} (Desktop)`, family.desktopFolder);
    makeEntry(`${family.key}-mobile`, `${family.label} (Mobile)`, family.mobileFolder);
  });

  return entries;
}

function buildManifest(clientIndex) {
  return Object.entries(clientIndex).map(([clientId, client]) => {
    const baseWidgets = buildWidgetEntries();

    const uniqueByPath = baseWidgets.reduce((acc, widget) => {
      const key = `${widget.id}:${widget.path}`;
      if (!acc.seen.has(key)) {
        acc.seen.add(key);
        acc.items.push(widget);
      }
      return acc;
    }, { items: [], seen: new Set() }).items;

    return {
      clientId,
      clientLabel: client.name || clientId,
      themes: client.themes.map(theme => ({
        themeId: theme.id,
        themeName: theme.name,
        css: `/theme-generator/output/client-themes/${clientId}/${theme.file}`,
        widgets: uniqueByPath
      }))
    };
  });
}

function run() {
  const generateThemePath = path.join(rootDir, 'theme-generator', 'v1', 'generate-theme-v2.mjs');
  if (!fs.existsSync(generateThemePath)) {
    throw new Error('generate-theme-v2.mjs not found.');
  }
  if (!fs.existsSync(DEFAULT_THEME_JSON)) {
    throw new Error('preview/themes/default.json missing.');
  }
  if (!fs.existsSync(CLIENT_THEMES_PATH)) { console.warn("⚠️  CLIENT_THEMES_PATH not found, skipping build. This is OK for Cloudflare Pages deployment."); process.exit(0); }
  const clientIndex = JSON.parse(fs.readFileSync(CLIENT_THEMES_PATH, 'utf8'));
  const manifest = buildManifest(clientIndex);
  fs.writeFileSync(MANIFEST_OUT, JSON.stringify(manifest, null, 2));
  console.log(`Wrote ${MANIFEST_OUT}`);

  fs.mkdirSync(DIST_DIR, { recursive: true });
  const { spawnSync } = require('child_process');
  const result = spawnSync(process.execPath, [generateThemePath, DEFAULT_THEME_JSON, DEFAULT_THEME_OUT], {
    stdio: 'inherit'
  });
  if (result.error) {
    throw result.error;
  }
  if (typeof result.status === 'number' && result.status !== 0) {
    throw new Error(`generate-theme-v2.mjs exited with status ${result.status}`);
  }
  console.log(`Generated default preview CSS at ${DEFAULT_THEME_OUT}`);
}

try {
  run();
} catch (err) {
  console.error(err);
  process.exit(1);
}
