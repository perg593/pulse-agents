# Proxy System Overview

## Purpose
- Load arbitrary external sites inside the preview dashboard while bypassing `X-Frame-Options`/`frame-ancestors` and common consent overlays.
- Rewrite all network activity (HTML, JS, CSS, images, XHR/fetch) to traverse the proxy so cross-origin restrictions do not break previews.
- Standardize error handling for upstream failures (403s, MIME/type mismatches) to keep the preview usable.

## Components
- **Cloudflare Worker proxy** (`functions/proxy.js`)
  - Production path: `/proxy?url=<encoded target>`.
  - Validates/allowlists targets, enforces simple in-memory rate limits, and sanitizes sensitive cookies before forwarding.
  - Builds upstream headers mirroring real browser signals (`User-Agent`, `Accept-*`, `Sec-Fetch-*`) and respects POST/PUT bodies.
  - Strips frame-blocking headers and forwards caching/CORS headers to the browser.
  - Rewrites HTML responses: injects `<base>`, rewrites URL-bearing attributes and CSS `url()`, injects consent cleanup, URL-rewriting runtime, and framework-error fallback. Adds a 403 banner when sites block embedding.
  - Detects expected MIME (via `Accept` or extension) and fixes cases where upstream returns HTML error pages for JS/CSS requests by emitting typed stubs.
  - Error path returns typed JS/CSS/JSON payloads so loaders do not crash on proxy failures.

- **Local background proxy server** (`preview/scripts/background-proxy-server.js`)
  - Node/Express implementation used in local preview (`RUN_BACKGROUND_PROXY`, `BACKGROUND_PROXY_PORT`, centralized `config/ports.js`).
  - Same `/proxy` contract and feature set as the Worker: allow/block lists, cookie sanitization, rate limiting, header normalization, MIME fixes, HTML rewriting, consent hiding, and 403 banner injection.
  - Adds body parsers for form/text/raw payloads and a persistent `__pi_proxy_target` cookie to keep target context across navigations.
  - Started automatically by `scripts/launch/services.sh`; can be disabled or re-pointed per README guidance.

- **Client helper** (`preview/app/services/proxy.js`)
  - Discovers the proxy origin (`window.__PI_PROXY_ORIGIN__` propagates through parent/opener frames) and wraps absolute URLs with `/proxy?url=…`.
  - Avoids double-proxying and leaves same-origin/local URLs untouched.
  - Used by preview UI to route background URLs and asset requests through the currently active proxy instance.

- **Integration test** (`tests/integration/preview/demo-proxy.test.mjs`)
  - Health-checks the proxy, verifies 403 banner injection, loads demo URLs from the shared sheet/fallback JSON, and asserts URL rewriting for HTML.
  - Runs standalone or via `npm test` with optional `PROXY_BASE_URL` override.

## Request Lifecycle
1. **Preview issues URL**: UI resolves background URL via `resolveProxyUrl()`, using `__PI_PROXY_ORIGIN__` configured in preview HTML or deployment env.
2. **Proxy validates target**: Allowlist/blocklist guard against localhost/loopback; non-http(s) protocols are rejected.
3. **Header shaping**: Proxy constructs realistic browser headers, filters sensitive cookies, and forwards POST/PUT bodies.
4. **Upstream fetch**: Follows redirects; applies rate limits and CORS.
5. **Response normalization**:
   - Removes `X-Frame-Options` and `frame-ancestors` CSP to permit iframe embedding.
   - Copies cache/CORS headers that callers may rely on.
6. **Content handling**:
   - **HTML**: Injects `<base>`, rewrites resource URLs to `/proxy?url=…`, injects runtime URL interception (fetch/XHR/script/link/img/iframe/audio/image constructors, innerHTML/outerHTML), hides consent banners, and installs a Vue/Nuxt SSR fallback plus optional 403 banner.
   - **JS/CSS**: Preserves content type; if upstream sends HTML error for a JS/CSS fetch, emits typed stub to keep loaders alive.
   - **Binary/other**: Streams bytes with passthrough headers.
7. **Browser runtime**: Injected script keeps subsequent dynamic requests proxied, even for code-split chunks, dynamic imports, or scripts created after load.

## Interaction with the Rest of the Application
- **Preview dashboard backgrounds**: When a user loads an external site as the preview background, the URL is wrapped via `resolveProxyUrl()`. The iframe then receives HTML rewritten by the proxy so all subresources route back through the proxy and remain embeddable.
- **Theme exploration & demos**: By stripping frame-blocking headers and hiding consent overlays, the preview can render target sites cleanly for screenshotting, theming, and interactive demos without CORS breakage.
- **Service launch scripts**: `scripts/launch/services.sh` starts the background proxy (port from `config/ports.js` or `BACKGROUND_PROXY_PORT`). Disabling it (`RUN_BACKGROUND_PROXY=0`) leaves local backgrounds same-origin for Stripe/demo scenarios.
- **Production deployment**: Swap `window.__PI_PROXY_ORIGIN__` in preview HTML to point at the deployed Worker (`functions/proxy.js`). The browser helper then routes all proxied URLs to that origin while keeping local assets unproxied.
- **Error visibility**: 403 banners and SSR fallback protect preview UI from blank/blocked pages; MIME-type normalization prevents module loaders from crashing when upstream sends HTML.

## Configuration Reference
- `BACKGROUND_PROXY_PORT`, `RUN_BACKGROUND_PROXY`: local server control (defaults: 3100, enabled).
- `BACKGROUND_PROXY_ALLOWLIST`, `BACKGROUND_PROXY_BLOCKLIST`: host gating (`*` + block localhost by default).
- `PROXY_SENSITIVE_COOKIE_PATTERNS`: comma list of cookie name fragments to strip (defaults to session/auth/token/csrf/jwt/etc.).
- `PROXY_RATE_LIMIT_MAX`: per-IP requests/minute for local proxy; Worker uses in-memory defaults (100/min).
- `__PI_PROXY_ORIGIN__`: injected in preview HTML; consumed by `getProxyOrigin()` to build proxied URLs in-browser.

## Operational Notes
- **Security**: No credentials are logged; cookies are filtered before forwarding. Blocklist protects against loopback SSRF.
- **Performance**: HTML rewriting and script injection run only for `text/html`; binary assets stream unchanged. Rate limits prevent abuse.
- **Testing**: Run `node tests/integration/preview/demo-proxy.test.mjs` (or `npm test`) with the proxy running to verify URL rewriting and 403 handling across demo targets.
