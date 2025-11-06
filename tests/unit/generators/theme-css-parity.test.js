const test = require('node:test');
const assert = require('node:assert/strict');
const { compileTheme } = require('../../../theme-generator/v1/src/theme-css.js');

const compile = (overrides = {}) => {
  const result = compileTheme(overrides);
  assert.deepEqual(result.errors, [], `Expected no compile errors. Errors: ${result.errors}`);
  return result.css;
};

test('generates CSS with CSS variables and base styles', () => {
  const css = compile();

  assert.ok(css.includes('#_pi_surveyWidgetContainer {'), 'Expected CSS variables block present');
  assert.ok(css.includes('--pi-color-text:'), 'Expected text color variable present');
  assert.ok(css.includes('--pi-color-background:'), 'Expected background color variable present');
  assert.ok(css.includes('#_pi_surveyWidgetContainer,\n#_pi_surveyWidgetContainer *'), 'Missing container reset');
  assert.ok(css.includes('color: var(--pi-color-text);'), 'Expected CSS variable usage for text color');
  assert.ok(css.includes('background-color: var(--pi-color-background);'), 'Expected CSS variable usage for background');
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

test('font family uses CSS variable', () => {
  const css = compile();

  assert.ok(css.includes('--pi-typography-font-family:'), 'Expected font family variable present');
  assert.ok(css.includes('font-family: var(--pi-typography-font-family);'), 'Expected CSS variable usage for font family');
  // Helvetica Neue is a valid fallback in the default font stack
  assert.ok(css.includes('system-ui'), 'Expected system-ui in font stack');
});
