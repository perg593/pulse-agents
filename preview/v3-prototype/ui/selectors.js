/** Canonical names used by Step‑2 spec. */
export const N = {
  // Preview toolbar
  previewUrl: 'previewUrl',
  deviceDesktop: 'deviceDesktop',
  deviceTablet: 'deviceTablet',
  deviceMobile: 'deviceMobile',
  placementBR: 'placementBR',
  placementBL: 'placementBL',
  placementTR: 'placementTR',
  placementTL: 'placementTL',
  safeArea: 'safeArea',
  reload: 'reload',

  // Preview frame
  frame: 'pi-v3-frame',

  // Agent section
  agentSelect: 'agentSelect',
  launchAgent: 'launchAgent',
  agentPlacement: 'agentPlacement',
  agentVariant: 'agentVariant',
  codeSnippet: 'codeSnippet',

  // Appearance
  themeMode: 'themeMode',
  themeSourceUrl: 'themeSourceUrl',
  generateTheme: 'generateTheme',
  generatedThemes: 'generatedThemes',
  themePreset: 'themePreset',
  brandColor: 'brandColor',
  cornerRadius: 'cornerRadius',
  density: 'density',

  // Triggers
  triggerPresent: 'triggerPresent',
  triggerExit: 'triggerExit',
  triggerScroll: 'triggerScroll',
  triggerTimer: 'triggerTimer',
  triggerRage: 'triggerRage',

  // Examples
  industry: 'industry',
  example: 'example',

  // Tools + Log
  tagStatus: 'tagStatus',
  agentStatus: 'agentStatus',
  showLog: 'showLog',
  resetDemo: 'resetDemo',
  logPanel: 'logPanel'
};

const SPECIAL_FALLBACK = {
  deviceDesktop: '.pi-v3__toolbar [data-device="Desktop"]',
  deviceTablet: '.pi-v3__toolbar [data-device="Tablet"]',
  deviceMobile: '.pi-v3__toolbar [data-device="Mobile"]',
  placementBR: '.pi-v3__toolbar [data-toolbar-placement="BR"]',
  placementBL: '.pi-v3__toolbar [data-toolbar-placement="BL"]',
  placementTR: '.pi-v3__toolbar [data-toolbar-placement="TR"]',
  placementTL: '.pi-v3__toolbar [data-toolbar-placement="TL"]',
  agentPlacement: '.pi-v3__accordion-item[data-section="agent"] .pi-v3__segment[aria-label="Placement"]',
  agentVariant: '#pi-v3-variant',
  codeSnippet: '#pi-v3-embed-link',
  themeMode: '.pi-v3__tabs',
  themeSourceUrl: '#pi-v3-theme-url',
  generateTheme: '#pi-v3-generate-theme',
  generatedThemes: '#pi-v3-theme-suggestions',
  themePreset: '#pi-v3-saved-themes',
  brandColor: '#pi-v3-brand-color',
  cornerRadius: '#pi-v3-corner-radius',
  density: '#pi-v3-density',
  triggerPresent: '#pi-v3-trigger-present',
  triggerExit: '.pi-v3__trigger-grid [data-trigger="exit-intent"]',
  triggerScroll: '.pi-v3__trigger-grid [data-trigger="scroll-depth"]',
  triggerTimer: '.pi-v3__trigger-grid [data-trigger="idle"]',
  triggerRage: '.pi-v3__trigger-grid [data-trigger="rage-click"]',
  industry: '#pi-v3-industry',
  example: '#pi-v3-usecase',
  tagStatus: '#pi-v3-tag-status',
  agentStatus: '#pi-v3-agent-status',
  showLog: '#pi-v3-show-log',
  resetDemo: '#pi-v3-reset-demo',
  logPanel: '.pi-v3__log-panel'
};

function candidates(canonical) {
  const kebab = canonical.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase();
  return [
    `[data-el="${canonical}"]`,
    `#${canonical}`,
    `#pi-v3-${kebab}`,
    SPECIAL_FALLBACK[canonical]
  ].filter(Boolean);
}

const warned = new Set();

export function UI(name) {
  for (const selector of candidates(name)) {
    const el = document.querySelector(selector);
    if (el) return el;
  }
  if (!warned.has(name)) {
    console.warn('[v3] UI selector not found:', name, candidates(name));
    warned.add(name);
  }
  return null;
}

export function UIAll(name) {
  const matches = [];
  for (const selector of candidates(name)) {
    const found = document.querySelectorAll(selector);
    if (found.length) {
      matches.push(...found);
      break;
    }
  }
  return matches;
}

export function aliasDom() {
  Object.values(N).forEach((canonical) => {
    const el = UI(canonical);
    if (el && !el.hasAttribute('data-el')) {
      el.setAttribute('data-el', canonical);
    }
  });
}
