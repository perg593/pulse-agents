/**
 * Analytics and tracking domains to block from proxying
 * These scripts are non-essential for site functionality and often break when proxied
 * @fileoverview Analytics domain blocklist configuration
 */

/**
 * Default list of analytics/tracking domains to block
 * @type {string[]}
 */
const DEFAULT_ANALYTICS_BLOCKLIST = [
  'googletagmanager.com',
  'google-analytics.com',
  'googleadservices.com',
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'analytics.google.com',
  'gtag/js',
  'gtm.js',
  'facebook.net',
  'facebook.com/tr',
  'fbcdn.net',
  'adservice.google',
  'adsystem.amazon',
  'amazon-adsystem.com',
  'bing.com/ms/clr',
  'bat.bing.com',
  'scorecardresearch.com',
  'quantserve.com',
  'outbrain.com',
  'taboola.com',
  'adsrvr.org',
  'adnxs.com',
  'rubiconproject.com',
  'pubmatic.com',
  'criteo.com',
  'adsafeprotected.com',
  'advertising.com',
  'adtechus.com'
];

/**
 * Parse analytics blocklist from environment variable or use defaults
 * @param {string|undefined} envValue - Environment variable value (comma-separated)
 * @returns {string[]} Array of domain patterns to block
 */
function parseAnalyticsBlocklist(envValue) {
  if (!envValue) {
    return DEFAULT_ANALYTICS_BLOCKLIST.slice();
  }
  
  const custom = envValue
    .split(',')
    .map(entry => entry.trim())
    .filter(Boolean);
  
  // Merge with defaults, removing duplicates
  const combined = [...DEFAULT_ANALYTICS_BLOCKLIST, ...custom];
  return [...new Set(combined)];
}

/**
 * Check if a URL should be blocked based on analytics blocklist
 * @param {string} url - URL to check
 * @param {string[]} blocklist - List of domain patterns to block
 * @returns {boolean} True if URL should be blocked
 */
function shouldBlockAnalyticsUrl(url, blocklist) {
  if (!url || typeof url !== 'string') return false;
  
  try {
    const urlObj = new URL(url);
    const hostname = urlObj.hostname.toLowerCase();
    const pathname = urlObj.pathname.toLowerCase();
    
    // Check if hostname or path matches any blocklist pattern
    return blocklist.some(pattern => {
      const lowerPattern = pattern.toLowerCase();
      return hostname.includes(lowerPattern) || pathname.includes(lowerPattern);
    });
  } catch (e) {
    // If URL parsing fails, check if pattern appears in the raw URL string
    const lowerUrl = url.toLowerCase();
    return blocklist.some(pattern => {
      return lowerUrl.includes(pattern.toLowerCase());
    });
  }
}

module.exports = {
  DEFAULT_ANALYTICS_BLOCKLIST,
  parseAnalyticsBlocklist,
  shouldBlockAnalyticsUrl
};
