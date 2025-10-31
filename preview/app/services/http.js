export async function fetchJson(url, { cacheBust = true } = {}) {
  const fetchUrl = cacheBust ? withCacheBust(url) : url;
  const res = await fetch(fetchUrl, { cache: 'no-cache' });
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url} (${res.status})`);
  }
  return res.json();
}

export async function fetchText(url, { cacheBust = true } = {}) {
  const fetchUrl = cacheBust ? withCacheBust(url) : url;
  const res = await fetch(fetchUrl, { cache: 'no-cache' });
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url} (${res.status})`);
  }
  return res.text();
}

function withCacheBust(url) {
  const hasQuery = url.includes('?');
  const sep = hasQuery ? '&' : '?';
  return `${url}${sep}t=${Date.now()}`;
}
