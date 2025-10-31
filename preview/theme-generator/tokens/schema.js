// Token schema describing core and advanced knobs for the theme generator.
// Each entry maps a token path to its default value, associated CSS variable name,
// and metadata used by the UI (core vs. advanced).

const TOKEN_SCHEMA = [
  // Color tokens
  {
    path: ['colors', 'primary'],
    cssVar: '--pi-color-primary',
    label: 'Primary color',
    type: 'color',
    core: true,
    default: '#2563eb'
  },
  {
    path: ['colors', 'primaryHover'],
    cssVar: '--pi-color-primary-hover',
    label: 'Primary hover',
    type: 'color',
    core: false,
    default: '#1d4ed8'
  },
  {
    path: ['colors', 'primaryActive'],
    cssVar: '--pi-color-primary-active',
    label: 'Primary active',
    type: 'color',
    core: false,
    default: '#1e3a8a'
  },
  {
    path: ['colors', 'secondary'],
    cssVar: '--pi-color-secondary',
    label: 'Secondary color',
    type: 'color',
    core: false,
    default: '#8b5cf6'
  },
  {
    path: ['colors', 'text'],
    cssVar: '--pi-color-text',
    label: 'Text color',
    type: 'color',
    core: true,
    default: '#1f2937'
  },
  {
    path: ['colors', 'bg'],
    cssVar: '--pi-color-background',
    label: 'Background',
    type: 'color',
    core: true,
    default: '#ffffff'
  },
  {
    path: ['colors', 'muted'],
    cssVar: '--pi-color-muted',
    label: 'Muted text',
    type: 'color',
    core: true,
    default: '#6b7280'
  },
  {
    path: ['colors', 'answerBorder'],
    cssVar: '--pi-color-answer-border',
    label: 'Answer border',
    type: 'color',
    core: false,
    default: '#d1d5db'
  },
  {
    path: ['colors', 'radioBorder'],
    cssVar: '--pi-color-radio-border',
    label: 'Radio border',
    type: 'color',
    core: false,
    default: '#9ca3af'
  },
  {
    path: ['colors', 'inputBorder'],
    cssVar: '--pi-color-input-border',
    label: 'Input border',
    type: 'color',
    core: false,
    default: '#cbd5f5'
  },
  {
    path: ['colors', 'inputFocus'],
    cssVar: '--pi-color-input-focus',
    label: 'Input focus ring',
    type: 'color',
    core: false,
    default: '#1d4ed8'
  },
  {
    path: ['colors', 'onPrimary'],
    cssVar: '--pi-color-on-primary',
    label: 'On primary',
    type: 'color',
    core: false,
    default: '#ffffff'
  },

  // Typography
  {
    path: ['typography', 'fontFamily'],
    cssVar: '--pi-typography-font-family',
    label: 'Base font family',
    type: 'font',
    core: true,
    default: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif'
  },
  {
    path: ['typography', 'lineHeights', 'question'],
    cssVar: '--pi-typography-line-height-question',
    label: 'Question line height',
    type: 'length',
    core: false,
    default: '1.25'
  },
  {
    path: ['typography', 'lineHeights', 'answer'],
    cssVar: '--pi-typography-line-height-answer',
    label: 'Answer line height',
    type: 'length',
    core: false,
    default: '1.4'
  },
  {
    path: ['typography', 'lineHeights', 'body'],
    cssVar: '--pi-typography-line-height-body',
    label: 'Body line height',
    type: 'length',
    core: false,
    default: '1.5'
  },
  {
    path: ['typography', 'sizes', 'question'],
    cssVar: '--pi-typography-size-question',
    label: 'Question size',
    type: 'length',
    core: true,
    default: '28px'
  },
  {
    path: ['typography', 'sizes', 'answer'],
    cssVar: '--pi-typography-size-answer',
    label: 'Answer size',
    type: 'length',
    core: false,
    default: '16px'
  },
  {
    path: ['typography', 'sizes', 'body'],
    cssVar: '--pi-typography-size-body',
    label: 'Body size',
    type: 'length',
    core: false,
    default: '16px'
  },
  {
    path: ['typography', 'sizes', 'caption'],
    cssVar: '--pi-typography-size-caption',
    label: 'Caption size',
    type: 'length',
    core: false,
    default: '14px'
  },
  {
    path: ['typography', 'weights', 'question'],
    cssVar: '--pi-typography-weight-question',
    label: 'Question weight',
    type: 'weight',
    core: true,
    default: '600'
  },
  {
    path: ['typography', 'weights', 'answer'],
    cssVar: '--pi-typography-weight-answer',
    label: 'Answer weight',
    type: 'weight',
    core: false,
    default: '500'
  },
  {
    path: ['typography', 'weights', 'body'],
    cssVar: '--pi-typography-weight-body',
    label: 'Body weight',
    type: 'weight',
    core: false,
    default: '400'
  },
  {
    path: ['typography', 'weights', 'caption'],
    cssVar: '--pi-typography-weight-caption',
    label: 'Caption weight',
    type: 'weight',
    core: false,
    default: '400'
  },
  {
    path: ['typography', 'closeButtonFamily'],
    cssVar: '--pi-typography-close-family',
    label: 'Close button font',
    type: 'font',
    core: false,
    default: 'system-ui, sans-serif'
  },
  {
    path: ['typography', 'closeButtonSize'],
    cssVar: '--pi-typography-close-size',
    label: 'Close button size',
    type: 'length',
    core: false,
    default: '32px'
  },

  // Layout & shape
  {
    path: ['layout', 'gapRow'],
    cssVar: '--pi-layout-gap-row',
    label: 'Row gap',
    type: 'length',
    core: false,
    default: '10px'
  },
  {
    path: ['layout', 'gapCol'],
    cssVar: '--pi-layout-gap-col',
    label: 'Column gap',
    type: 'length',
    core: false,
    default: '12px'
  },
  {
    path: ['shape', 'widgetRadius'],
    cssVar: '--pi-shape-widget-radius',
    label: 'Widget radius',
    type: 'length',
    core: true,
    default: '16px'
  },
  {
    path: ['shape', 'controlRadius'],
    cssVar: '--pi-shape-control-radius',
    label: 'Answer radius',
    type: 'length',
    core: true,
    default: '10px'
  },
  {
    path: ['shape', 'buttonRadius'],
    cssVar: '--pi-shape-button-radius',
    label: 'Button radius',
    type: 'length',
    core: true,
    default: '8px'
  },

  // Shadows
  {
    path: ['shadows', 'widget'],
    cssVar: '--pi-shadow-widget',
    label: 'Widget shadow',
    type: 'shadow',
    core: false,
    default: '0 20px 60px rgba(15, 23, 42, 0.12)'
  },
  {
    path: ['shadows', 'bar'],
    cssVar: '--pi-shadow-bar',
    label: 'Bar shadow',
    type: 'shadow',
    core: false,
    default: '0px -1px 12px rgba(15, 23, 42, 0.2)'
  },

  // Button state tokens (state machine)
  {
    path: ['states', 'button', 'default', 'fill'],
    cssVar: '--pi-button-fill-default',
    label: 'Button fill',
    type: 'color',
    core: false,
    default: '#2563eb'
  },
  {
    path: ['states', 'button', 'default', 'border'],
    cssVar: '--pi-button-border-default',
    label: 'Button border',
    type: 'border',
    core: false,
    default: '1px solid #2563eb'
  },
  {
    path: ['states', 'button', 'default', 'shadow'],
    cssVar: '--pi-button-shadow-default',
    label: 'Button shadow',
    type: 'shadow',
    core: false,
    default: '0 2px 6px rgba(37, 99, 235, 0.35)'
  },
  {
    path: ['states', 'button', 'default', 'color'],
    cssVar: '--pi-button-color-default',
    label: 'Button text color',
    type: 'color',
    core: false,
    default: '#ffffff'
  },
  {
    path: ['states', 'button', 'hover', 'fill'],
    cssVar: '--pi-button-fill-hover',
    label: 'Button hover fill',
    type: 'color',
    core: false,
    default: '#1d4ed8'
  },
  {
    path: ['states', 'button', 'hover', 'border'],
    cssVar: '--pi-button-border-hover',
    label: 'Button hover border',
    type: 'border',
    core: false,
    default: '1px solid #1d4ed8'
  },
  {
    path: ['states', 'button', 'hover', 'shadow'],
    cssVar: '--pi-button-shadow-hover',
    label: 'Button hover shadow',
    type: 'shadow',
    core: false,
    default: '0 4px 10px rgba(29, 78, 216, 0.3)'
  },
  {
    path: ['states', 'button', 'hover', 'color'],
    cssVar: '--pi-button-color-hover',
    label: 'Button hover text',
    type: 'color',
    core: false,
    default: '#ffffff'
  },
  {
    path: ['states', 'button', 'active', 'fill'],
    cssVar: '--pi-button-fill-active',
    label: 'Button active fill',
    type: 'color',
    core: false,
    default: '#1e3a8a'
  },
  {
    path: ['states', 'button', 'active', 'border'],
    cssVar: '--pi-button-border-active',
    label: 'Button active border',
    type: 'border',
    core: false,
    default: '1px solid #1e3a8a'
  },
  {
    path: ['states', 'button', 'active', 'shadow'],
    cssVar: '--pi-button-shadow-active',
    label: 'Button active shadow',
    type: 'shadow',
    core: false,
    default: '0 2px 4px rgba(30, 58, 138, 0.35)'
  },
  {
    path: ['states', 'button', 'active', 'color'],
    cssVar: '--pi-button-color-active',
    label: 'Button active text',
    type: 'color',
    core: false,
    default: '#ffffff'
  },
  {
    path: ['states', 'button', 'focus', 'fill'],
    cssVar: '--pi-button-fill-focus',
    label: 'Button focus fill',
    type: 'color',
    core: false,
    default: '#1d4ed8'
  },
  {
    path: ['states', 'button', 'focus', 'border'],
    cssVar: '--pi-button-border-focus',
    label: 'Button focus border',
    type: 'border',
    core: false,
    default: '2px solid #ffffff'
  },
  {
    path: ['states', 'button', 'focus', 'shadow'],
    cssVar: '--pi-button-shadow-focus',
    label: 'Button focus shadow',
    type: 'shadow',
    core: false,
    default: '0 0 0 4px rgba(29, 78, 216, 0.25)'
  },
  {
    path: ['states', 'button', 'focus', 'color'],
    cssVar: '--pi-button-color-focus',
    label: 'Button focus text',
    type: 'color',
    core: false,
    default: '#ffffff'
  },
  {
    path: ['states', 'button', 'selected', 'fill'],
    cssVar: '--pi-button-fill-selected',
    label: 'Button selected fill',
    type: 'color',
    core: false,
    default: '#ffffff'
  },
  {
    path: ['states', 'button', 'selected', 'border'],
    cssVar: '--pi-button-border-selected',
    label: 'Button selected border',
    type: 'border',
    core: false,
    default: '2px solid #2563eb'
  },
  {
    path: ['states', 'button', 'selected', 'shadow'],
    cssVar: '--pi-button-shadow-selected',
    label: 'Button selected shadow',
    type: 'shadow',
    core: false,
    default: '0 0 0 2px rgba(37, 99, 235, 0.2)'
  },
  {
    path: ['states', 'button', 'selected', 'color'],
    cssVar: '--pi-button-color-selected',
    label: 'Button selected text',
    type: 'color',
    core: false,
    default: '#2563eb'
  },

  // Focus styles
  {
    path: ['focus', 'color'],
    cssVar: '--pi-focus-outline-color',
    label: 'Focus outline color',
    type: 'color',
    core: false,
    default: '#5e9ed6'
  },
  {
    path: ['focus', 'style'],
    cssVar: '--pi-focus-outline-style',
    label: 'Focus outline style',
    type: 'text',
    core: false,
    default: 'solid'
  },
  {
    path: ['focus', 'width'],
    cssVar: '--pi-focus-outline-width',
    label: 'Focus outline width',
    type: 'length',
    core: false,
    default: '2px'
  },
  {
    path: ['focus', 'offset'],
    cssVar: '--pi-focus-outline-offset',
    label: 'Focus outline offset',
    type: 'length',
    core: false,
    default: '2px'
  },
  {
    path: ['focus', 'radius'],
    cssVar: '--pi-focus-outline-radius',
    label: 'Focus outline radius',
    type: 'length',
    core: false,
    default: 'var(--pi-shape-control-radius)'
  },

  // Button layout tokens
  {
    path: ['buttons', 'paddingDesktop'],
    cssVar: '--pi-button-padding-desktop',
    label: 'Button padding (desktop)',
    type: 'length',
    core: false,
    default: '12px 28px'
  },
  {
    path: ['buttons', 'paddingMobile'],
    cssVar: '--pi-button-padding-mobile',
    label: 'Button padding (mobile)',
    type: 'length',
    core: false,
    default: '12px 20px'
  },
  {
    path: ['buttons', 'fontWeight'],
    cssVar: '--pi-button-font-weight',
    label: 'Button font weight',
    type: 'weight',
    core: false,
    default: '600'
  },

  // Radio geometry
  {
    path: ['answers', 'radioStyle'],
    cssVar: '--pi-answers-radio-style',
    label: 'Radio style',
    type: 'text',
    core: false,
    default: 'dot'
  },
  {
    path: ['answers', 'radioOuter'],
    cssVar: '--pi-answers-radio-outer-size',
    label: 'Radio outer size',
    type: 'length',
    core: false,
    default: '18px'
  },
  {
    path: ['answers', 'radioInner'],
    cssVar: '--pi-answers-radio-inner-size',
    label: 'Radio inner size',
    type: 'length',
    core: false,
    default: '10px'
  },
  {
    path: ['answers', 'radioBorderWidth'],
    cssVar: '--pi-answers-radio-border-width',
    label: 'Radio border width',
    type: 'length',
    core: false,
    default: '2px'
  },
  {
    path: ['answers', 'tileSize'],
    cssVar: '--pi-answers-tile-min-height',
    label: 'Answer min height',
    type: 'length',
    core: false,
    default: '56px'
  },
  {
    path: ['answers', 'textAlignWhenRadioOn'],
    cssVar: '--pi-answers-text-align-radio-on',
    label: 'Answer alignment (radio on)',
    type: 'text',
    core: false,
    default: 'left'
  },
  {
    path: ['answers', 'textAlignWhenRadioOff'],
    cssVar: '--pi-answers-text-align-radio-off',
    label: 'Answer alignment (radio off)',
    type: 'text',
    core: false,
    default: 'center'
  },

  // Input styling
  {
    path: ['inputs', 'style'],
    cssVar: '--pi-input-style',
    label: 'Input style',
    type: 'text',
    core: false,
    default: 'box'
  },
  {
    path: ['inputs', 'height'],
    cssVar: '--pi-input-height',
    label: 'Input height',
    type: 'length',
    core: false,
    default: '48px'
  },
  {
    path: ['inputs', 'radius'],
    cssVar: '--pi-input-radius',
    label: 'Input radius',
    type: 'length',
    core: false,
    default: '10px'
  }
];

const CORE_TOKEN_PATHS = TOKEN_SCHEMA.filter((entry) => entry.core).map((entry) => entry.path);

const defaultObject = {};
for (const entry of TOKEN_SCHEMA) {
  assignPath(defaultObject, entry.path, entry.default);
}

/**
 * Ensure nested object path exists and set value.
 */
function assignPath(target, path, value) {
  let cursor = target;
  const lastIndex = path.length - 1;
  path.forEach((segment, index) => {
    if (index === lastIndex) {
      cursor[segment] = value;
      return;
    }
    if (!cursor[segment] || typeof cursor[segment] !== 'object') {
      cursor[segment] = {};
    }
    cursor = cursor[segment];
  });
}

/**
 * Retrieve nested value by path.
 */
function getPath(source, path) {
  return path.reduce((acc, key) => {
    if (acc && Object.prototype.hasOwnProperty.call(acc, key)) {
      return acc[key];
    }
    return undefined;
  }, source);
}

/**
 * Set nested value by path.
 */
function setPath(target, path, value) {
  assignPath(target, path, value);
  return target;
}

/**
 * Deep clone JSON-friendly data.
 */
function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

/**
 * Merge provided tokens with defaults from the schema.
 */
function applyTokenDefaults(tokens = {}) {
  const merged = clone(defaultObject);
  mergeRecursive(merged, tokens);
  return merged;
}

function mergeRecursive(target, source) {
  if (!source || typeof source !== 'object') {
    return;
  }
  for (const [key, value] of Object.entries(source)) {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      if (!target[key] || typeof target[key] !== 'object') {
        target[key] = {};
      }
      mergeRecursive(target[key], value);
    } else {
      target[key] = value;
    }
  }
}

/**
 * Flatten tokens into a map of css variable name => value.
 */
function buildCssVariableMap(tokens = {}) {
  const map = {};
  TOKEN_SCHEMA.forEach((entry) => {
    const value = getPath(tokens, entry.path);
    if (value !== undefined && value !== null && value !== '') {
      map[entry.cssVar] = value;
    }
  });
  return map;
}

export {
  TOKEN_SCHEMA,
  CORE_TOKEN_PATHS,
  defaultObject as DEFAULT_TOKEN_VALUES,
  applyTokenDefaults,
  buildCssVariableMap,
  getPath,
  setPath
};
