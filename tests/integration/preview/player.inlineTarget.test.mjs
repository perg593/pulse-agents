import { strict as assert } from 'node:assert';
import { JSDOM } from 'jsdom';

const dom = new JSDOM(
  `
<!doctype html>
<body>
  <div id="inline-host">
    <div class="inline-canvas">
      <div id="inline-target" class="inline-target"></div>
    </div>
  </div>
</body>
`,
  { url: 'https://player.test/app/survey/player.html' }
);

global.window = dom.window;
global.document = dom.window.document;

try {
  const { ensureInlineTarget } = await import('../app/survey/inlineTarget.js');
  const placeholder = document.getElementById('inline-target');

  const selectorExisting = ensureInlineTarget('#inline-target', { document, placeholder });
  assert.equal(selectorExisting, '#inline-target', 'matching selector is left intact');
  assert.equal(document.getElementById('inline-target'), placeholder, 'placeholder remains when selector exists');

  const selectorFallback = ensureInlineTarget('[data-slot="survey"]', { document, placeholder });
  assert.equal(selectorFallback, '#pi-inline-target', 'fallback selector returned when target missing');

  const fallbackEl = document.getElementById('pi-inline-target');
  assert.ok(fallbackEl, 'fallback element created');
  assert.ok(fallbackEl.classList.contains('inline-target'), 'fallback retains inline-target styling');
  assert.strictEqual(fallbackEl, placeholder, 'original placeholder reused as fallback');

  console.log('inline target tests passed');
} finally {
  delete global.window;
  delete global.document;
  dom.window.close();
}
