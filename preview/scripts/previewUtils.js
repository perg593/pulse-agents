export async function loadManifest(path) {
  const res = await fetch(path, { cache: 'no-cache' });
  if (!res.ok) {
    throw new Error(`Failed to load preview manifest (${res.status})`);
  }
  return res.json();
}

export async function loadThemeCSS(href) {
  const res = await fetch(href, { cache: 'no-cache' });
  if (!res.ok) {
    throw new Error(`Failed to fetch CSS ${href}`);
  }
  return res.text();
}

export async function computeContrast(cssHref, clientId, themeId) {
  try {
    const cssText = await loadThemeCSS(cssHref);
    return evaluateContrast(cssText, clientId, themeId);
  } catch (error) {
    console.warn('Contrast check error:', error);
    return [{ name: 'Contrast check', status: 'warn', value: 'failed' }];
  }
}

function evaluateContrast(cssText, clientId, themeId) {
  const colorVars = extractCSSVariables(cssText);
  const pairs = [
    { name: 'Widget text on background', fg: '--pi-text', bg: '--pi-bg', minimum: 4.5 },
    { name: 'CTA text on CTA background', fg: '--pi-on-primary', bg: '--pi-primary', minimum: 4.5 },
    { name: 'CTA hover text', fg: '--pi-on-primary', bg: '--pi-primary-hover', minimum: 4.5 }
  ];

  return pairs.map(pair => {
    const fg = toRGB(colorVars[pair.fg]);
    const bg = toRGB(colorVars[pair.bg]);
    if (!fg || !bg) {
      return { name: pair.name, status: 'warn', value: 'unknown colors' };
    }
    const ratio = contrastRatio(fg, bg);
    const status = ratio >= pair.minimum ? 'pass' : 'fail';
    return { name: pair.name, status, value: `${ratio.toFixed(2)}:1` };
  });
}

function extractCSSVariables(cssText) {
  const rootMatch = cssText.match(/#_pi_surveyWidgetContainer\s*{([^}]+)}/);
  if (!rootMatch) return {};
  const block = rootMatch[1];
  const vars = {};
  block.split(';').forEach(line => {
    const [prop, value] = line.split(':').map(part => part && part.trim());
    if (prop && prop.startsWith('--')) {
      vars[prop] = value;
    }
  });
  return vars;
}

function toRGB(token) {
  if (!token) return null;
  const clean = token.replace(/!important/g, '').trim();
  if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(clean)) {
    const hex = clean.slice(1);
    const full = hex.length === 3 ? hex.split('').map(ch => ch + ch).join('') : hex;
    const int = parseInt(full, 16);
    return {
      r: (int >> 16) & 255,
      g: (int >> 8) & 255,
      b: int & 255
    };
  }
  const rgb = clean.match(/^rgba?\(([^)]+)\)$/i);
  if (rgb) {
    const [r, g, b] = rgb[1].split(',').map(v => parseFloat(v.trim()));
    return { r, g, b };
  }
  return null;
}

function contrastRatio(fg, bg) {
  const [lf, lb] = [luminance(fg), luminance(bg)];
  const [lighter, darker] = lf >= lb ? [lf, lb] : [lb, lf];
  return (lighter + 0.05) / (darker + 0.05);
}

function luminance({ r, g, b }) {
  const transform = v => {
    const normalized = v / 255;
    return normalized <= 0.03928 ? normalized / 12.92 : Math.pow((normalized + 0.055) / 1.055, 2.4);
  };
  const [nr, ng, nb] = [transform(r), transform(g), transform(b)];
  return 0.2126 * nr + 0.7152 * ng + 0.0722 * nb;
}
