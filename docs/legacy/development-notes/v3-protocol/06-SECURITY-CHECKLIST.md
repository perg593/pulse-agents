# Security Checklist — Bridge/Player on Cloudflare Pages

**Goal:** Only trusted frames talk, no code injection, and sensible headers in Pages.

---

## A) Messaging
- [ ] `postMessage` **targetOrigin** is the exact Player origin (never `"*"` in production).
- [ ] Each receiver validates `event.origin` == expected origin.
- [ ] Player locks `bridgeOrigin` on first message and uses that for all replies.

## B) Iframe sandboxing
- [ ] Player iframe uses `sandbox="allow-scripts allow-same-origin"` (add permissions only if absolutely required).
- [ ] No `allow-popups` or `allow-top-navigation` unless a user action truly requires it.

## C) Content Security Policy (Pages `_headers`)
Add to your `preview/v3/_headers` or project headers:
```
/*
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; frame-ancestors 'none';
  X-Content-Type-Options: nosniff
  Referrer-Policy: no-referrer-when-downgrade
```
_Tune `style-src` if your curated themes are cross-origin; ideally host under the same origin._

## D) CSS & payload handling
- [ ] Apply themes via `<link rel="stylesheet">` (curated) or inert `<style>` (generated). Never evaluate JS in CSS.
- [ ] Treat all message payloads as **data**. No `eval`, Function constructor, or dynamic script injection.
- [ ] Limit theme token ranges (e.g., radius 0–24) to avoid pathological values.

## E) Logging & telemetry
- [ ] Never log PII. Redact identifiers if present.
- [ ] Error objects surfaced to UI are friendly (no stack traces). Raw stacks go only to console or telemetry when needed.

## F) Timeouts & DoS hygiene
- [ ] Handshake timeout 5s; ack timeout 3s; abort stale promises.
- [ ] Heartbeat every 30s; two misses mark inactive (no tight loops).
- [ ] Debounce geometry/status posts to ≥16ms.

## G) Build & deploy
- [ ] Cloudflare Pages publishes only `preview/v3/` (output dir).
- [ ] Relative asset URLs (`./v3.css`, `./theme/*.css`) so preview/prod both work.
- [ ] `_redirects` file present for SPA refresh: `/*  /index.html  200`.

## H) Reviews
- [ ] Protocol version noted at the top of `bridge.js` and `player.js`.
- [ ] Code owners review any change to message types or error taxonomy.
