const test = require('node:test');
const assert = require('node:assert/strict');
const SimpleSiteAnalyzer = require('../../../theme-generator/analyze-site.js');

test('fallback analysis returns normalized structures', () => {
  const analyzer = new SimpleSiteAnalyzer();
  const fallback = analyzer.getFallbackAnalysis('https://example.com');

  assert.equal(fallback.url, 'https://example.com');
  assert.ok(Array.isArray(fallback.colors.backgrounds), 'background colors should be an array');
  assert.ok(Array.isArray(fallback.colors.textColors), 'text colors should be an array');
  assert.ok(Array.isArray(fallback.colors.accentColors), 'accent colors should be an array');
  assert.ok(Array.isArray(fallback.colors.borderColors), 'border colors should be an array');

  assert.ok(Array.isArray(fallback.fonts.families), 'font families should be an array');
  assert.ok(fallback.fonts.families.length > 0, 'fallback should provide at least one font family');
  assert.ok(Array.isArray(fallback.fonts.sizes), 'font sizes should be an array');
  assert.ok(Array.isArray(fallback.fonts.weights), 'font weights should be an array');
});
