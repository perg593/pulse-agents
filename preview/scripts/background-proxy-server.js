#!/usr/bin/env node

const express = require('express');
const { URL } = require('url');
const path = require('path');

// Load centralized port configuration
let PORT;
try {
  const configPath = path.resolve(__dirname, '../../config/ports.js');
  const config = require(configPath);
  PORT = config.getPort('BACKGROUND_PROXY_PORT', 'development');
} catch (error) {
  // Fallback to environment variable or default
  PORT = Number.parseInt(process.env.BACKGROUND_PROXY_PORT || '3100', 10);
}

const app = express();
const ALLOWLIST = (process.env.BACKGROUND_PROXY_ALLOWLIST || '*')
  .split(',')
  .map((entry) => entry.trim())
  .filter(Boolean);
const BLOCKED_HOSTS = (process.env.BACKGROUND_PROXY_BLOCKLIST || 'localhost,127.,::1')
  .split(',')
  .map((entry) => entry.trim())
  .filter(Boolean);

const DEFAULT_USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 PulsePreviewProxy/1.0';

const CONSENT_BANNER_SELECTORS = [
  '#onetrust-banner-sdk',
  '.onetrust-pc-dark-filter',
  '.optanon-alert-box-wrapper',
  '.cc-window',
  '.cc-banner',
  '.cookie-consent',
  '.cookie-consent-container',
  '#cookie-consent',
  '.js-consent-banner',
  '.app-consent-banner',
  '.osano-cm-window',
  '.osano-cm-wrapper',
  '.cky-consent-container',
  '.cky-overlay',
  '.gdprCookieMessage',
  '#cookiebanner',
  '.cookieBanner',
  '.truste_overlay',
  '.truste_box_overlay'
];

function isHostAllowed(hostname) {
  if (!hostname) return false;
  const lower = hostname.toLowerCase();
  if (BLOCKED_HOSTS.some((blocked) => lower.startsWith(blocked))) {
    return false;
  }
  if (ALLOWLIST.includes('*')) return true;
  return ALLOWLIST.some((pattern) => {
    if (!pattern) return false;
    const normalized = pattern.toLowerCase();
    return lower === normalized || lower.endsWith(`.${normalized}`);
  });
}

function resolveTarget(raw) {
  let url;
  try {
    url = new URL(raw);
  } catch (error) {
    throw new Error('Invalid URL');
  }
  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error('Only http/https protocols supported');
  }
  if (!isHostAllowed(url.hostname)) {
    throw new Error(`Host not allowed: ${url.hostname}`);
  }
  return url;
}

app.options('/proxy', (req, res) => {
  const allowHeaders = req.headers['access-control-request-headers'] || 'Accept,Content-Type,User-Agent';
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', allowHeaders);
  res.setHeader('access-control-allow-methods', 'GET,HEAD,OPTIONS');
  res.setHeader('access-control-max-age', '86400');
  res.status(204).end();
});

app.get('/background-proxy/health', (req, res) => {
  res.json({
    status: 'ok',
    port: PORT,
    allowlist: ALLOWLIST
  });
});

app.get('/proxy', async (req, res) => {
  const targetRaw = req.query.url;
  if (!targetRaw || typeof targetRaw !== 'string') {
    res.status(400).json({ error: 'Missing url query parameter' });
    return;
  }

  let target;
  try {
    target = resolveTarget(targetRaw);
  } catch (error) {
    res.status(400).json({ error: error.message });
    return;
  }

  try {
    const incomingHeaders = req.headers;
    const upstreamHeaders = {
      'User-Agent': incomingHeaders['user-agent'] || DEFAULT_USER_AGENT,
      Accept: incomingHeaders['accept'] || '*/*',
      'Accept-Language': incomingHeaders['accept-language'] || 'en-US,en;q=0.9',
      'Accept-Encoding': incomingHeaders['accept-encoding'] || 'gzip, deflate, br',
      Referer: incomingHeaders['referer'] || target.origin,
      Origin: target.origin,
      Cookie: incomingHeaders.cookie || undefined,
      'Sec-Fetch-Dest': incomingHeaders['sec-fetch-dest'] || 'document',
      'Sec-Fetch-Mode': incomingHeaders['sec-fetch-mode'] || 'navigate',
      'Sec-Fetch-Site': incomingHeaders['sec-fetch-site'] || 'none'
    };

    Object.keys(upstreamHeaders).forEach((key) => {
      if (upstreamHeaders[key] === undefined) {
        delete upstreamHeaders[key];
      }
    });

    const response = await fetch(target.toString(), {
      headers: upstreamHeaders,
      redirect: 'follow'
    });

    const contentType = response.headers.get('content-type') || '';
    res.status(response.status);
    const allowHeaders = req.headers['access-control-request-headers'] || 'Accept,Content-Type,User-Agent';
    res.setHeader('access-control-allow-origin', '*');
    res.setHeader('access-control-allow-headers', allowHeaders);
    res.setHeader('access-control-allow-methods', 'GET,HEAD,OPTIONS');
    res.setHeader('access-control-expose-headers', 'cache-control,expires,pragma,content-type');
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
        const baseHref = target.href.replace(/[^/]*$/, '');
        body = body.replace(
          /<head([^>]*)>/i,
          `<head$1><base href="${baseHref}">`
        );
      }
      body = injectConsentCleanup(body);
      res.send(body);
    } else {
      const buffer = Buffer.from(await response.arrayBuffer());
      res.send(buffer);
    }
  } catch (error) {
    console.error('Proxy error', target.toString(), error.message);
    res.status(502).json({
      error: `Failed to fetch ${target.toString()}: ${error.message}`
    });
  }
});

app.listen(PORT, () => {
  console.log(`Background proxy listening on http://localhost:${PORT}`);
});

function injectConsentCleanup(html) {
  let output = html;
  const styleBlock = `\n<style data-pi-proxy="consent-hide">${CONSENT_BANNER_SELECTORS.join(
    ', '
  )}{display:none!important;visibility:hidden!important;opacity:0!important;}</style>`;
  if (/<head[^>]*>/i.test(output)) {
    output = output.replace(/<head([^>]*)>/i, `<head$1>${styleBlock}`);
  } else {
    output = `${styleBlock}${output}`;
  }

  const scriptBlock = `\n<script data-pi-proxy="consent-hide">(function(){const selectors=${JSON.stringify(
    CONSENT_BANNER_SELECTORS
  )};const hide=()=>{selectors.forEach((sel)=>{try{document.querySelectorAll(sel).forEach((node)=>{if(!node)return;node.style.setProperty('display','none','important');node.style.setProperty('visibility','hidden','important');node.style.setProperty('opacity','0','important');node.setAttribute('data-pi-proxy-hidden','true');if(node.parentElement&&node.parentElement.children.length===1&&node.parentElement.innerText.trim().length<2){node.parentElement.style.setProperty('display','none','important');}});}catch(e){}});};hide();['load','DOMContentLoaded'].forEach((evt)=>window.addEventListener(evt,hide,{once:false}));const interval=setInterval(hide,500);setTimeout(()=>clearInterval(interval),5000);})();</script>`;

  if (/<\/body>/i.test(output)) {
    output = output.replace(/<\/body>/i, `${scriptBlock}</body>`);
  } else {
    output = `${output}${scriptBlock}`;
  }
  return output;
}
