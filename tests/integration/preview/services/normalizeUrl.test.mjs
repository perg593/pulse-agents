import { strict as assert } from 'node:assert';
import { JSDOM } from 'jsdom';
import { normalizeUrl } from '../../../../preview/app/services/background.js';

const dom = new JSDOM('<!doctype html>', { url: 'https://preview.test/' });
global.window = dom.window;
global.document = dom.window.document;

try {
  assert.equal(
    normalizeUrl('example.com/page.html'),
    'https://example.com/page.html',
    'domain-first url gets https scheme'
  );

  assert.equal(
    normalizeUrl('//cdn.example.com/x.html'),
    'https://cdn.example.com/x.html',
    'protocol-relative urls gain https scheme'
  );

  assert.equal(
    normalizeUrl('/local.html', { base: 'https://demo.local' }),
    'https://demo.local/local.html',
    'root-relative paths resolve against base'
  );

  assert.equal(
    normalizeUrl('path/to/file.html', { base: 'https://demo.local/app/' }),
    'https://demo.local/app/path/to/file.html',
    'relative path resolves against base'
  );

  assert.equal(
    normalizeUrl('example.com/a.html', {
      preferProxy: true,
      proxyOrigin: 'https://proxy.local'
    }),
    'https://proxy.local/proxy?url=https%3A%2F%2Fexample.com%2Fa.html',
    'proxy preference rewrites absolute urls'
  );

  console.log('normalizeUrl tests passed');
} finally {
  delete global.window;
  delete global.document;
  dom.window.close();
}
