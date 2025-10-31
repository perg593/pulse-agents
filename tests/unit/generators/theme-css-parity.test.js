const test = require('node:test');
const assert = require('node:assert/strict');
const { compileTheme } = require('../../../theme-generator/src/theme-css.js');

const compile = (overrides = {}) => {
  const result = compileTheme(overrides);
  assert.deepEqual(result.errors, [], `Expected no compile errors. Errors: ${result.errors}`);
  return result.css;
};

test('template keeps curated scaffold and swaps baseline colors', () => {
  const css = compile();

  assert.ok(css.includes('/* DEFAULT START */'), 'Expected curated default header present');
  assert.ok(css.includes('div#_pi_surveyWidgetContainer,\n div#_pi_surveyWidgetContainer.mobile-enabled'), 'Missing container reset');
  assert.ok(css.includes('color: #222222;'), 'Default text color substitution missing');
  assert.ok(css.includes('background-color: #ffffff;'), 'Default background color substitution missing');
});

test('color tokens are substituted when overrides are provided', () => {
  const css = compile({
    colors: {
      text: '#123456',
      bg: '#0a0a0a',
      primary: '#ff0000',
      primaryHover: '#00ff00',
      primaryActive: '#0000ff',
      onPrimary: '#ffffff',
      answerBorder: '#222222',
      radioBorder: '#333333',
      inputBorder: '#654321',
      inputFocus: '#abcdef',
      muted: '#555555'
    }
  });

  assert.ok(css.includes('#123456'), 'Custom text color missing');
  assert.ok(css.includes('#0a0a0a'), 'Custom background color missing');
  assert.ok(css.includes('#ff0000'), 'Custom primary color missing');
  assert.ok(css.includes('#00ff00'), 'Custom primary hover color missing');
  assert.ok(css.includes('#abcdef'), 'Custom focus color missing');
  assert.ok(css.includes('#654321'), 'Custom input border color missing');
});

test('font family is substituted', () => {
  const css = compile();

  assert.ok(!css.includes('"Helvetica Neue"'), 'Expected curated font family to be replaced');
  assert.ok(css.includes('system-ui, sans-serif'), 'Expected default font family present');
});
