const PROXY_MARKER = '/proxy?url=';

function getWindow() {
  if (typeof window === 'undefined') return null;
  return window;
}

export function getProxyOrigin() {
  const w = getWindow();
  if (!w) return '';
  const origin = findProxyOrigin(w);
  if (origin && !w.__PI_PROXY_ORIGIN__) {
    try {
      w.__PI_PROXY_ORIGIN__ = origin;
    } catch (_error) {
      // Read-only environments can ignore the assignment.
    }
  }
  return origin;
}

export function resolveProxyUrl(target) {
  if (!target && target !== '') return target;
  const normalizedTarget = normalizeTarget(target);
  if (!normalizedTarget) return normalizedTarget;

  const proxyOrigin = getProxyOrigin();
  if (!proxyOrigin) return normalizedTarget;

  if (!/^https?:\/\//i.test(normalizedTarget)) {
    return normalizedTarget;
  }

  if (isAlreadyProxied(normalizedTarget, proxyOrigin)) {
    return normalizedTarget;
  }

  try {
    const parsed = new URL(normalizedTarget);
    const w = getWindow();
    if (w && parsed.origin === w.location.origin) {
      return normalizedTarget;
    }
  } catch (_error) {
    // Unable to parse; fall back to proxying.
  }

  const base = proxyOrigin.replace(/\/$/, '');
  const encoded = encodeURIComponent(normalizedTarget);
  return `${base}${PROXY_MARKER}${encoded}`;
}

function normalizeTarget(value) {
  if (value === null || value === undefined) return '';
  const trimmed = String(value).trim();
  if (!trimmed) return '';

  if (trimmed.startsWith('//')) {
    const w = getWindow();
    const protocol = w ? w.location.protocol : 'https:';
    return `${protocol}${trimmed}`;
  }

  return trimmed;
}

function isAlreadyProxied(url, proxyOrigin) {
  if (!url) return false;
  if (url.includes(PROXY_MARKER)) return true;
  if (!proxyOrigin) return false;
  const base = proxyOrigin.replace(/\/$/, '');
  return url.startsWith(base + PROXY_MARKER);
}

function readOrigin(win) {
  if (!win) return '';
  const raw = win.__PI_PROXY_ORIGIN__;
  if (typeof raw === 'string' && raw.trim()) {
    return raw.trim();
  }
  return '';
}

function findProxyOrigin(win, depth = 0) {
  if (!win || depth > 10) return '';
  const own = readOrigin(win);
  if (own) return own;

  let parentOrigin = '';
  try {
    const parent = win.parent;
    if (parent && parent !== win) {
      parentOrigin = findProxyOrigin(parent, depth + 1);
    }
  } catch (_error) {
    // Cross-origin parent; ignore.
  }
  if (parentOrigin) return parentOrigin;

  let openerOrigin = '';
  try {
    const opener = win.opener;
    if (opener && opener !== win) {
      openerOrigin = findProxyOrigin(opener, depth + 1);
    }
  } catch (_error) {
    // Cross-origin opener; ignore.
  }
  return openerOrigin;
}
