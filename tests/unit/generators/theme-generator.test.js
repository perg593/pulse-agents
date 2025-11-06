const test = require('node:test');
const assert = require('node:assert/strict');
const SimpleThemeGenerator = require('../../../theme-generator/v1/theme-generator.js');
const { compileTheme } = require('../../../theme-generator/v1/src/theme-css.js');

const mockAnalysis = {
  url: 'https://brand.example.com',
  colors: {
    backgrounds: ['#ffffff', '#f4f4f5'],
    textColors: ['#1f2937', '#111827'],
    accentColors: ['#2563eb', '#d946ef']
  },
  fonts: {
    families: ['Inter'],
    sizes: ['16px', '18px'],
    weights: ['400', '500']
  }
};

test('theme generator produces tokens that compile without errors', () => {
  const generator = new SimpleThemeGenerator(mockAnalysis);
  const themes = generator.generateThemes();

  assert.equal(themes.length, 4);

  themes.forEach(theme => {
    assert.ok(theme.tokens, `Expected tokens to exist for ${theme.name}`);
    assert.equal(typeof theme.tokens.name, 'string');
    assert.equal(typeof theme.tokens.colors.primary, 'string');

    const result = compileTheme(theme.tokens);
    assert.deepEqual(result.errors, [], `Expected no compile errors for ${theme.name}`);
    assert.ok(Array.isArray(result.warnings), 'Expected warnings array to be returned');
    assert.ok(result.css.includes('#_pi_surveyWidgetContainer'));
  });
});

test('compileTheme accepts various radio styles', () => {
  // Test that 'pills' is accepted (current implementation doesn't validate radio style values)
  const result = compileTheme({
    answers: { radioStyle: 'pills' }
  });

  assert.ok(result.css !== null, 'Expected CSS to be generated');
  assert.deepEqual(result.errors, [], 'Expected no errors');
  assert.ok(result.css.includes('--pi-answers-radio-style: pills;'), 'Expected radio style variable to be set');
});

test('compileTheme warns when widget contrast is too low', () => {
  const result = compileTheme({
    widgets: {
      topbar: {
        bg: '#ffffff',
        text: '#ffffff'
      }
    }
  });

  assert.deepEqual(result.errors, []);
  assert.ok(result.warnings.some(msg => msg.includes('widgets.topbar')), 'Expected widget contrast warning');
});
