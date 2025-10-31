import { fetchJson } from './http.js';

const MANIFEST_URL = '/theme-generator/output/preview-manifest.json';

export async function loadManifest() {
  const data = await fetchJson(MANIFEST_URL);
  return Array.isArray(data) ? data : [];
}

export function listClients(manifest) {
  return manifest.map((client) => ({
    value: client.clientId,
    label: client.clientLabel || client.clientId,
    themes: client.themes || []
  }));
}

export function listThemes(clientEntry) {
  if (!clientEntry) return [];
  return (clientEntry.themes || []).map((theme) => ({
    value: theme.themeId,
    label: theme.themeName || theme.themeId,
    css: theme.css,
    widgets: theme.widgets || []
  }));
}

export function listWidgets(themeEntry) {
  if (!themeEntry) return [];
  return (themeEntry.widgets || []).map((widget) => ({
    value: widget.id,
    label: widget.label || widget.id,
    path: widget.path
  }));
}

export function findClient(manifest, clientId) {
  return manifest.find((client) => client.clientId === clientId) || null;
}

export function findTheme(clientEntry, themeId) {
  if (!clientEntry) return null;
  return (clientEntry.themes || []).find((theme) => theme.themeId === themeId) || null;
}

export function findWidget(themeEntry, widgetId) {
  if (!themeEntry) return null;
  return (themeEntry.widgets || []).find((widget) => widget.id === widgetId) || null;
}
