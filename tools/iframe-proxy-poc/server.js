#!/usr/bin/env node

/**
 * Lightweight proof-of-concept proxy that removes frame-blocking headers
 * so we can iframe demo sites like https://www.vyloyhcp.com.
 *
 * Usage:
 *   node tools/iframe-proxy-poc/server.js
 *   open http://localhost:3100
 */

const express = require('express');

const app = express();
const PORT = Number.parseInt(process.env.PROXY_POC_PORT || '3100', 10);
const DEFAULT_TARGET = 'https://www.vyloyhcp.com';

app.get('/', (_req, res) => {
  res.type('html').send(`
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>Proxy POC – ${DEFAULT_TARGET}</title>
        <style>
          body {
            margin: 0;
            font-family: system-ui, sans-serif;
            background: #0f172a;
            color: #e2e8f0;
            display: flex;
            flex-direction: column;
            height: 100vh;
          }
          header {
            padding: 16px 24px;
            background: rgba(15, 23, 42, 0.9);
            border-bottom: 1px solid rgba(148, 163, 184, 0.2);
          }
          header h1 {
            margin: 0;
            font-size: 18px;
          }
          iframe {
            flex: 1;
            border: none;
            width: 100%;
          }
        </style>
      </head>
      <body>
        <header>
          <h1>Proxy POC → ${DEFAULT_TARGET}</h1>
        </header>
        <iframe src="/proxy?url=${encodeURIComponent(DEFAULT_TARGET)}" title="Proxy demo"></iframe>
      </body>
    </html>
  `);
});

app.get('/proxy', async (req, res) => {
  const target = req.query.url;
  if (!target || typeof target !== 'string') {
    res.status(400).json({ error: 'Missing url query parameter' });
    return;
  }

  try {
    const response = await fetch(target, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0; +https://pulseinsights.com)'
      }
    });

    const contentType = response.headers.get('content-type') || '';
    res.status(response.status);
    if (contentType) {
      res.setHeader('content-type', contentType);
    }

    const passthroughHeaders = ['cache-control', 'expires', 'pragma'];
    passthroughHeaders.forEach((header) => {
      const value = response.headers.get(header);
      if (value) {
        res.setHeader(header, value);
      }
    });

    if (contentType.includes('text/html')) {
      let body = await response.text();
      if (!/base\s+href=/i.test(body)) {
        body = body.replace(
          /<head([^>]*)>/i,
          `<head$1><base href="${target}">`
        );
      }
      res.send(body);
    } else {
      const arrayBuffer = await response.arrayBuffer();
      res.send(Buffer.from(arrayBuffer));
    }
  } catch (error) {
    console.error('Proxy fetch failed', error);
    res.status(502).json({
      error: `Failed to fetch ${target}: ${error.message}`
    });
  }
});

app.listen(PORT, () => {
  console.log(`Proxy POC running at http://localhost:${PORT}`);
  console.log(`Preview: http://localhost:${PORT}/`);
});
