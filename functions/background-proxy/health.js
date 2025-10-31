function parseList(value, fallback) {
  if (!value) return fallback.slice();
  return String(value)
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}

export async function onRequest({ request, env }) {
  const headers = new Headers({
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,OPTIONS',
    'access-control-allow-headers': request.headers.get('access-control-request-headers') || ''
  });

  if (request.method === 'OPTIONS') {
    headers.set('access-control-max-age', '86400');
    return new Response(null, { status: 204, headers });
  }

  const payload = {
    status: 'ok',
    allowlist: parseList(env.BACKGROUND_PROXY_ALLOWLIST, ['*']),
    blocklist: parseList(env.BACKGROUND_PROXY_BLOCKLIST, ['localhost', '127.', '::1'])
  };

  headers.set('content-type', 'application/json');

  return new Response(JSON.stringify(payload), {
    status: 200,
    headers
  });
}
