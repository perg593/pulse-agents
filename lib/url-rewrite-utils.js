/**
 * @fileoverview URL rewrite validation helpers.
 */

const DISALLOWED_SCHEMES = ['javascript:', 'data:', 'blob:', 'chrome:', 'about:'];

/**
 * Determines whether a string is safe and supported for rewriting.
 *
 * @param {string} value
 * @returns {boolean}
 */
function isRewritableUrl(value) {
  if (!value || typeof value !== 'string') return false;

  const trimmed = value.trim();
  if (!trimmed) return false;

  // Reject any quotes (leading or stray).
  if (/[\'"]/.test(trimmed)) return false;

  const lower = trimmed.toLowerCase();

  if (DISALLOWED_SCHEMES.some((scheme) => lower.startsWith(scheme))) {
    return false;
  }

  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return true;
  }

  if (lower.startsWith('//')) {
    return true;
  }

  if (trimmed.startsWith('/')) {
    return true;
  }

  return false;
}

const URL_ATTRS = new Set([
  'src',
  'href',
  'action',
  'formaction',
  'poster',
  'data-src',
  'data-href',
  'xlink:href',
  'content',
]);

module.exports = {
  isRewritableUrl,
  URL_ATTRS,
};
