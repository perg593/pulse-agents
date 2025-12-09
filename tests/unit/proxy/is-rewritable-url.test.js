const path = require('path');
const { isRewritableUrl } = require('../../../lib/url-rewrite-utils');

function assert(condition, message) {
  if (!condition) {
    throw new Error(message || 'Assertion failed');
  }
}

function test(name, fn) {
  try {
    fn();
    console.log(`✓ ${name}`);
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(error.message);
    throw error;
  }
}

const shouldRewrite = ['/foo/bar.png', 'https://example.com/a/b', '//cdn.example.com/lib.js', '/foo'];
const shouldNotRewrite = [
  '"about:blank"',
  "'about:blank'",
  'about:blank',
  '"//fonts.googleapis.com"',
  "'https://fonts.googleapis.com/css2'",
  'javascript:alert(1)',
  'data:image/png;base64,iVBORw...',
  'fonts.googleapis.com/foo.css',
];

console.log(`Testing isRewritableUrl from ${path.join('lib', 'url-rewrite-utils.js')}`);

shouldRewrite.forEach((value) => {
  test(`Should allow rewriting: ${value}`, () => {
    assert(isRewritableUrl(value) === true, `Expected true for ${value}`);
  });
});

shouldNotRewrite.forEach((value) => {
  test(`Should block rewriting: ${value}`, () => {
    assert(isRewritableUrl(value) === false, `Expected false for ${value}`);
  });
});
