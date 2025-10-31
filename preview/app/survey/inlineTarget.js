const FALLBACK_ID = 'pi-inline-target';

function getDocument(doc) {
  if (doc) return doc;
  if (typeof window !== 'undefined' && window.document) {
    return window.document;
  }
  return null;
}

export function ensureInlineTarget(selector, { document: docOverride, placeholder } = {}) {
  const doc = getDocument(docOverride);
  if (!doc) {
    return selector || `#${FALLBACK_ID}`;
  }

  let target = null;
  if (selector) {
    try {
      target = doc.querySelector(selector);
    } catch (_error) {
      target = null;
    }
  }
  if (target) {
    return selector;
  }

  let fallback = doc.getElementById(FALLBACK_ID);
  if (!fallback) {
    if (placeholder && placeholder.parentNode) {
      fallback = placeholder;
      fallback.id = FALLBACK_ID;
    } else {
      fallback = doc.createElement('div');
      fallback.id = FALLBACK_ID;
      fallback.classList.add('inline-target');
      fallback.style.minHeight = '1px';
      const parent = placeholder?.parentNode || doc.body || doc.documentElement;
      parent.appendChild(fallback);
    }
  }

  if (!fallback.classList.contains('inline-target')) {
    fallback.classList.add('inline-target');
  }

  return `#${FALLBACK_ID}`;
}
