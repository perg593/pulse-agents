const SIMPLE_BACKGROUND = '/preview/simple-background.html';

function getWindowObject() {
  if (typeof window === 'undefined') {
    return null;
  }
  return window;
}

const PROXY_ORIGIN = (() => {
  const win = getWindowObject();
  return (win && typeof win.__PI_PROXY_ORIGIN__ === 'string' ? win.__PI_PROXY_ORIGIN__ : '').trim();
})();

export function loadBackground(frameEl, url) {
  if (!frameEl) return;
  const normalized = normalizeUrl(url);
  const effective = normalized || SIMPLE_BACKGROUND;

  if (frameEl.__pulseCleanseHandler) {
    frameEl.removeEventListener('load', frameEl.__pulseCleanseHandler);
  }

  frameEl.__pulseCleanseHandler = () => {
    cleanseFrame(frameEl);
  };

  frameEl.addEventListener('load', frameEl.__pulseCleanseHandler);
  const frameSrc = resolveFrameSrc(effective);
  frameEl.dataset.previewOriginalUrl = effective;
  frameEl.src = frameSrc;
}

export function loadSimpleBackground(frameEl) {
  loadBackground(frameEl, SIMPLE_BACKGROUND);
}

export function normalizeUrl(
  input,
  {
    base = getWindowObject()?.location?.origin || 'http://localhost',
    preferProxy = false,
    proxyOrigin
  } = {}
) {
  if (!input || typeof input !== 'string') return '';
  const trimmed = input.trim();
  if (!trimmed) return '';

  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(trimmed)) {
    return trimmed;
  }

  if (/^\/\//.test(trimmed)) {
    return `https:${trimmed}`;
  }

  const firstSegment = trimmed.split('/')[0];
  const segmentLooksLikeDomain =
    !trimmed.startsWith('/') &&
    (firstSegment.includes('.') || firstSegment.includes(':')) &&
    !/\.(html?|xhtml?)$/i.test(firstSegment);

  if (segmentLooksLikeDomain) {
    const absolute = `https://${trimmed}`;
    if (preferProxy && proxyOrigin) {
      const baseProxy = proxyOrigin.replace(/\/$/, '');
      return `${baseProxy}/proxy?url=${encodeURIComponent(absolute)}`;
    }
    return absolute;
  }

  if (trimmed.startsWith('/')) {
    try {
      return new URL(trimmed, base).toString();
    } catch (_error) {
      return trimmed;
    }
  }

  if (/^\.{1,2}\//.test(trimmed)) {
    try {
      return new URL(trimmed, base).toString();
    } catch (_error) {
      return trimmed;
    }
  }

  if (/\.(html?|xhtml?)$/i.test(trimmed)) {
    try {
      return new URL(trimmed, base).toString();
    } catch (_error) {
      return trimmed;
    }
  }

  try {
    return new URL(trimmed, base).toString();
  } catch (_error) {
    return trimmed;
  }
}

function shouldProxy(value) {
  if (!PROXY_ORIGIN) return false;
  if (!value) return false;
  const trimmed = String(value).trim();
  if (!/^https?:\/\//i.test(trimmed)) return false;
  if (trimmed.startsWith(PROXY_ORIGIN)) return false;
  if (trimmed.includes('/proxy?url=')) return false;
  const win = getWindowObject();
  if (win) {
    try {
      const parsed = new URL(trimmed, win.location.href);
      if (parsed.origin === win.location.origin) {
        return false;
      }
    } catch (_error) {
      /* ignore parse failure */
    }
  }
  return true;
}

function resolveFrameSrc(url) {
  if (!url) return url;
  if (!shouldProxy(url)) return url;
  const base = PROXY_ORIGIN.replace(/\/$/, '');
  const encoded = encodeURIComponent(url);
  if (!base) return `/proxy?url=${encoded}`;
  return `${base}/proxy?url=${encoded}`;
}

function cleanseFrame(frameEl) {
  try {
    const win = frameEl.contentWindow;
    const doc = win ? win.document : frameEl.contentDocument;
    if (!doc) return;

    const selectors = [
      'script[src*="pulseinsights.com"]',
      'script[src*="pulse-insights"]',
      'script[src*="pulseinsights"]',
      'script[data-pulse-tag]'
    ].join(',');

    doc.querySelectorAll(selectors).forEach((node) => {
      const parent = node.parentNode;
      if (parent) {
        parent.removeChild(node);
      }
    });

    doc.querySelectorAll('script').forEach((node) => {
      const text = node.textContent || '';
      if (/pulseinsights|pi\s*\(/i.test(text)) {
        const parent = node.parentNode;
        if (parent) {
          parent.removeChild(node);
        }
      }
    });

    if (win) {
      try {
        if (typeof win.pi === 'function') {
          const suppressed = [];
          const noop = function () {
            suppressed.push(arguments);
          };
          noop.q = suppressed;
          noop.l = Date.now();
          win.pi = noop;
        }
        if ('PulseInsightsObject' in win) {
          try {
            delete win.PulseInsightsObject;
          } catch (error) {
            win.PulseInsightsObject = undefined;
          }
        }
      } catch (error) {
        console.warn('Pulse tag window cleanup failed', error);
      }
    }
  } catch (error) {
    console.warn('Unable to cleanse background frame', error);
  }
}
