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

export async function onRequest(context) {
  const { request, env } = context;
  const incoming = new URL(request.url);
  if (request.method === 'OPTIONS') {
    return buildPreflightResponse(request);
  }

  if (request.method !== 'GET') {
    return withCors(jsonResponse({ error: 'Method not allowed' }, { status: 405 }), request);
  }

  const targetRaw = incoming.searchParams.get('url');
  if (!targetRaw) {
    return withCors(jsonResponse({ error: 'Missing url query parameter' }, { status: 400 }), request);
  }

  const allowlist = parseList(env.BACKGROUND_PROXY_ALLOWLIST, ['*']);
  const blocklist = parseList(env.BACKGROUND_PROXY_BLOCKLIST, ['localhost', '127.', '::1']);

  let target;
  try {
    target = resolveTarget(targetRaw, allowlist, blocklist);
  } catch (error) {
    return withCors(jsonResponse({ error: error.message }, { status: 400 }), request);
  }

  try {
    const upstreamHeaders = buildUpstreamHeaders(request.headers, target);
    const upstreamResponse = await fetch(target.toString(), {
      headers: upstreamHeaders,
      redirect: 'follow'
    });

    const responseHeaders = buildCorsHeaders(request.headers);
    copyPassthroughHeaders(upstreamResponse, responseHeaders);

    const contentType = upstreamResponse.headers.get('content-type') || '';
    if (contentType) {
      responseHeaders.set('content-type', contentType);
    }

    if (contentType.includes('text/html')) {
      let body = await upstreamResponse.text();
      body = ensureBaseHref(body, target);
      body = injectConsentCleanup(body);
      return new Response(body, {
        status: upstreamResponse.status,
        headers: responseHeaders
      });
    }

    const buffer = await upstreamResponse.arrayBuffer();
    return new Response(buffer, {
      status: upstreamResponse.status,
      headers: responseHeaders
    });
  } catch (error) {
    console.error('Proxy fetch failed', targetRaw, error);
    return withCors(
      jsonResponse({ error: `Failed to fetch ${target.toString()}: ${error.message}` }, { status: 502 }),
      request
    );
  }
}

function parseList(value, fallback) {
  if (!value) return fallback.slice();
  return String(value)
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function resolveTarget(raw, allowlist, blocklist) {
  let url;
  try {
    url = new URL(raw);
  } catch (_error) {
    throw new Error('Invalid URL');
  }

  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error('Only http/https protocols supported');
  }

  if (!isHostAllowed(url.hostname, allowlist, blocklist)) {
    throw new Error(`Host not allowed: ${url.hostname}`);
  }

  return url;
}

function isHostAllowed(hostname, allowlist, blocklist) {
  if (!hostname) return false;
  const lower = hostname.toLowerCase();
  if (blocklist.some((blocked) => lower.startsWith(blocked.toLowerCase()))) {
    return false;
  }
  if (allowlist.includes('*')) return true;
  return allowlist.some((entry) => {
    const normalized = entry.toLowerCase();
    return lower === normalized || lower.endsWith(`.${normalized}`);
  });
}

function buildUpstreamHeaders(headers, target) {
  const upstream = new Headers();
  const headerPairs = [
    ['user-agent', headers.get('user-agent') || DEFAULT_USER_AGENT],
    ['accept', headers.get('accept') || '*/*'],
    ['accept-language', headers.get('accept-language') || 'en-US,en;q=0.9'],
    ['accept-encoding', headers.get('accept-encoding') || 'gzip, deflate, br'],
    ['referer', headers.get('referer') || target.origin],
    ['origin', headers.get('origin') || target.origin],
    ['cookie', headers.get('cookie')]
  ];

  headerPairs.forEach(([key, value]) => {
    if (value) {
      try {
        upstream.set(key, value);
      } catch (_error) {
        // Ignore restricted headers (e.g. user-agent in some environments).
      }
    }
  });

  const secHeaders = [
    ['sec-fetch-dest', headers.get('sec-fetch-dest') || 'document'],
    ['sec-fetch-mode', headers.get('sec-fetch-mode') || 'navigate'],
    ['sec-fetch-site', headers.get('sec-fetch-site') || 'none']
  ];

  secHeaders.forEach(([key, value]) => {
    if (value) {
      upstream.set(key, value);
    }
  });

  return upstream;
}

function buildPreflightResponse(request) {
  const headers = buildCorsHeaders(request.headers);
  headers.set('access-control-max-age', '86400');
  return new Response(null, { status: 204, headers });
}

function buildCorsHeaders(requestHeaders) {
  const headers = new Headers();
  headers.set('access-control-allow-origin', '*');
  const allowHeaders =
    requestHeaders.get('access-control-request-headers') || 'Accept,Content-Type,User-Agent';
  headers.set('access-control-allow-headers', allowHeaders);
  headers.set('access-control-allow-methods', 'GET,HEAD,OPTIONS');
  headers.set('access-control-expose-headers', 'cache-control,expires,pragma,content-type');
  return headers;
}

function withCors(response, request) {
  const headers = buildCorsHeaders(request.headers);
  const merged = new Headers(response.headers);
  headers.forEach((value, key) => {
    merged.set(key, value);
  });
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: merged
  });
}

function copyPassthroughHeaders(upstreamResponse, headers) {
  ['cache-control', 'expires', 'pragma'].forEach((header) => {
    const value = upstreamResponse.headers.get(header);
    if (value) {
      headers.set(header, value);
    }
  });
}

function ensureBaseHref(html, target) {
  if (/<head[^>]*>/i.test(html) && /<base[^>]*>/i.test(html)) {
    return html;
  }
  const baseHref = target.href.replace(/[^/]*$/, '');
  if (/<head[^>]*>/i.test(html)) {
    return html.replace(/<head([^>]*)>/i, `<head$1><base href="${baseHref}">`);
  }
  return `<base href="${baseHref}">${html}`;
}

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

function jsonResponse(payload, init = {}) {
  const headers = new Headers(init.headers || {});
  headers.set('content-type', 'application/json');
  return new Response(JSON.stringify(payload), {
    ...init,
    headers
  });
}
