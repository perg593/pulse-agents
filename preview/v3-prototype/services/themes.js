import { store, setState } from '../v3.js';
import { log } from '../ui/log.js';
import { emit } from '../ui/events.js';
import { applyThemeHref, clearThemeHref } from '../adapter/pulse-adapter.js';
import { generateThemesFromUrl } from '../../basic/theme-generator-client.js';

const MANIFEST_URL = '/preview/v3/data/example-themes.json';

export async function loadExampleThemes() {
  try {
    const response = await fetch(MANIFEST_URL, { cache: 'no-cache' });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    const themes = flattenManifest(data);
    log('theme', 'event', `Loaded ${themes.length} example themes`);
    return themes;
  } catch (error) {
    log('theme', 'warn', 'Failed to load example themes', { error: String(error) });
    return [];
  }
}

export function applyThemeByHref(id, label, href) {
  if (!href) return;
  applyThemeHref(href);
  const descriptor = {
    id,
    label,
    origin: 'example',
    href
  };
  const next = new Map(store.stylesheetRegistry || []);
  next.set(id, descriptor);
  setState({
    stylesheetRegistry: next,
    activeThemeId: id
  });
  emit({ type: 'theme_applied', ts: Date.now(), themeId: id, origin: 'example' });
}

export function removeTheme(id) {
  const next = new Map(store.stylesheetRegistry || []);
  if (next.has(id)) {
    next.delete(id);
    setState({ stylesheetRegistry: next });
  }
  if (store.activeThemeId === id) {
    clearThemeHref();
    setState({ activeThemeId: undefined });
  }
}

export async function generateFromUrl(url) {
  revokeGeneratedAssets();
  try {
    const result = await generateThemesFromUrl(url);
    const descriptors = (result.themes || []).map((theme) => {
      const blob = new Blob([theme.css], { type: 'text/css' });
      const href = URL.createObjectURL(blob);
      return {
        id: theme.id,
        label: theme.name,
        origin: 'generated',
        blobUrl: href,
        tokens: theme.tokens || {},
        meta: theme.description ? { description: theme.description } : undefined
      };
    });
    const hrefs = descriptors.map((item) => item.blobUrl).filter(Boolean);
    setState({ generatedThemeAssets: hrefs });
    log('theme', 'event', `Generated ${descriptors.length} themes`);
    return descriptors;
  } catch (error) {
    emit({
      type: 'error',
      ts: Date.now(),
      code: 'gen_fail',
      message: 'Theme generation failed',
      data: { error: String(error) }
    });
    setState({ generatedThemeAssets: [] });
    return [];
  }
}

export function applyGeneratedTheme(theme) {
  if (!theme || !theme.blobUrl) return;
  applyThemeHref(theme.blobUrl);
  const descriptor = {
    id: theme.id,
    label: theme.label,
    origin: 'generated',
    blobUrl: theme.blobUrl,
    tokens: theme.tokens || {},
    meta: theme.meta
  };
  const next = new Map(store.stylesheetRegistry || []);
  next.set(theme.id, descriptor);
  setState({
    stylesheetRegistry: next,
    activeThemeId: theme.id
  });
  emit({ type: 'theme_applied', ts: Date.now(), themeId: theme.id, origin: 'generated' });
}

export function revokeGeneratedAssets() {
  const assets = store.generatedThemeAssets || [];
  assets.forEach((href) => {
    try {
      URL.revokeObjectURL(href);
    } catch {}
  });
  if (assets.length) {
    emit({ type: 'theme_revoked', ts: Date.now(), count: assets.length });
  }
  setState({ generatedThemeAssets: [] });
}

function flattenManifest(manifest) {
  if (!Array.isArray(manifest)) return [];
  const themes = [];
  manifest.forEach((client) => {
    const clientLabel = client.clientLabel || client.clientId;
    (client.themes || []).forEach((theme) => {
      themes.push({
        id: theme.themeId,
        label: `${clientLabel} — ${theme.themeName}`,
        origin: 'example',
        href: theme.css,
        meta: {
          clientId: client.clientId,
          widgets: theme.widgets || []
        }
      });
    });
  });
  return themes;
}
