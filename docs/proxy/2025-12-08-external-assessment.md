# Preview Proxy – NJTransit vs Localhost / Cloudflare Analysis

## 1. Context

This document explains what’s happening when the **Preview app** loads the NJ Transit “Train-To” page via the proxy, in two environments:

* **Localhost** proxy (e.g. `http://localhost:3100/proxy?url=…`)
* **Cloudflare Pages** proxy (e.g. `https://95abb1ec.pulse-agents-demo.pages.dev/proxy?url=…`)

The analysis is based on two DevTools console exports:

* `njt-06-local.log` – local Node/Express proxy
* `njt-06-95abb1ec.log` – Cloudflare Pages preview (with “Preserve log” enabled, so it captures multiple navigations)

The goal: understand why **localhost shows the NJTransit site “correctly”, while the Cloudflare run behaves differently and appears to push you toward `pulseinsights.com`**.

---

## 2. Main actors involved

Across both logs, the same core pieces are visible:

* **Preview shell** (`preview.js`)

  * Loads config from a Google Sheet
  * Decides which URL to load via the proxy (`loadHostPage`)
  * Boots the “player” iframe and handles widget placement + fallback

* **Bridge / Player** (`bridge.js`, `player.js`)

  * Runs inside the iframe
  * Talks to the preview shell
  * Loads `surveys.js` from `js.pulseinsights.com`

* **Proxy runtime** (the in-page JS “PI-Proxy” script)

  * Installs hooks:

    * `XMLHttpRequest` interception
    * `HTMLScriptElement.src` + `setAttribute`
    * `HTMLLinkElement.href`
    * `HTMLImageElement.src`
    * `HTMLIFrameElement.src`
    * `Image()` and `Audio()` constructors
  * Logs messages like:

    * `HTMLScriptElement.prototype.src interception installed`
    * `URL rewriting script initialization complete`
    * `Framework error handler installing/installed`
    * `Backed up SSR content from: #__nuxt`
    * `Content wiped again, re-restoring`

* **NJ Transit host page**

  * URL like:
    `https://www.njtransit.com/train-to?origin=...&destination=...`
  * Uses Nuxt (`_nuxt/BHrqiTBk.js`) and logs:

    * `[nuxt] error caught during app initialization Error: Context conflict`

* **3rd-party scripts**

  * HubSpot (`hs-analytics.net`, `hscollectedforms.net`, `track.hubspot.com`)
  * Cloudflare Insights (`static.cloudflareinsights.com`)
  * Autopilot (`cdn.bc0a.com`)
  * Google fonts, Google Translate, etc.

These are present in both environments; the differences are in **how** they’re wired and what the preview shell thinks the “host page” is.

---

## 3. What happens in the Cloudflare log (`njt-06-95abb1ec.log`)

### 3.1 Preview shell boot

Early lines show the preview environment starting up:

* `bridge.js:7 [bridge] module bootstrap {version: '2025-10-09-01'}`
* Multiple `[preview]` log objects:

  * Initializing basic preview
  * Loading config from Google Sheets (`fetchSurveySheet`)

This confirms:

* The **preview shell** is running from
  `https://95abb1ec.pulse-agents-demo.pages.dev/preview/app/...`
* It successfully fetches your survey config from Google Sheets.

### 3.2 Host page: `www.pulseinsights.com/agents`

Then the preview decides which URL to load:

```text
preview.js:2607 [preview] {... "Host page: https://www.pulseinsights.com/agents.", ...}
preview.js:762 Fetch finished loading: GET "https://95abb1ec.pulse-agents-demo.pages.dev/proxy?url=https%3A%2F%2Fwww.pulseinsights.com%2Fagents".
loadHostPage @ preview.js:762
```

So **at least one run in this captured log is explicitly loading**:

> `https://www.pulseinsights.com/agents`
> via
> `https://95abb1ec.pulse-agents-demo.pages.dev/proxy?url=...`

The proxy attaches:

```text
proxy?url=https%3A%2F%2Fwww.pulseinsights.com%2Fagents:641 [PI-Proxy] Script tag interception installed
proxy?url=https%3A%2F%2Fwww.pulseinsights.com%2Fagents:658 [PI-Proxy] Framework error handler installing...
proxy?url=https%3A%2F%2Fwww.pulseinsights.com%2Fagents:945 [PI-Proxy] Framework error handler installed
```

And the player loads:

```text
[bridge] load player {account: 'PI-81598442', host: 'survey.pulseinsights.com', proxyOrigin: 'https://95abb1ec.pulse-agents-demo.pages.dev'}
VM84 surveys-tag.js:42 [surveys-tag] surveys.js loaded {src: 'https://95abb1ec.pulse-agents-demo.pages.dev/proxy?url=https%3A%2F%2Fjs.pulseinsights.com%2Fsurveys.js'}
```

So in this phase:

* The preview is **intentionally** loading `pulseinsights.com/agents` as the host page.
* The player + surveys tag are behaving as they would on a normal PI site, just through the proxy.

This matches your subjective impression “Cloudflare redirects to pulseinsights.com” — in reality, **the preview config for that run is “host = pulseinsights.com/agents”**, and you’re seeing exactly that.

### 3.3 NJ Transit host page also appears in the same log

Because DevTools is in “Preserve log” mode, later in the same file we see **NJTransit** being loaded via the same proxy:

```text
Navigated to https://95abb1ec.pulse-agents-demo.pages.dev/proxy?url=https%3A%2F%2Fwww.njtransit.com%2Ftrain-to%3Forigin%3D...

proxy?url=https%3A%2F%2Fwww.njtransit.com%2Ftrain-to%3Forigin%3D... [PI-Proxy] Script tag interception installed
proxy?url=https%3A%2F%2Fwww.njtransit.com%2Ftrain-to%3Forigin%3D... [PI-Proxy] Framework error handler installing...
proxy?url=https%3A%2F%2Fwww.njtransit.com%2Ftrain-to%3Forigin%3D... [PI-Proxy] Framework error handler installed
```

We see the familiar pattern:

* URL rewriting installed for scripts/links/images/iframes
* SSR backup from `#__nuxt`
* MutationObserver watching `#__nuxt`

We also see the same Nuxt error as in localhost:

```text
BHrqiTBk.js:20 [nuxt] error caught during app initialization Error: Context conflict
    at r (...)
    at Object.set (...)
```

And some fallback activity from the preview shell:

```text
[preview] widget fallback waiting for widget {attempt: N}
scheduleWidgetFallbackRetry @ preview.js:4248
applyWidgetFallbackStyles @ preview.js:4137
```

So **both** of these are true inside this single log:

1. The preview loads `www.pulseinsights.com/agents` (twice, based on timestamps ~17:42:53 and 17:43:09).
2. The preview also loads `www.njtransit.com/train-to?...` via the proxy.
3. The widget fallback logic keeps firing, which suggests the player or widget isn’t stabilizing as expected on NJT.

Because everything is preserved in one log, it’s easy to conflate these into “Cloudflare takes me to pulseinsights.com instead of NJTransit”. But strictly speaking, the log shows **multiple runs / navigations**.

---

## 4. What happens in the localhost log (`njt-06-local.log`)

This file looks like a clean run where **only the NJTransit host page** is relevant.

### 4.1 Proxy runtime boot

First lines:

```text
XMLHttpRequest interception installed
[PI-Proxy] HTMLScriptElement.prototype.src interception installed
HTMLScriptElement.prototype.setAttribute interception installed
[PI-Proxy] HTMLLinkElement.prototype.href interception installed
[PI-Proxy] HTMLIFrameElement.prototype.src interception installed
[PI-Proxy] HTMLImageElement.prototype.src interception installed
...
[PI-Proxy] Script tag interception installed
[PI-Proxy] URL rewriting script initialization complete
[PI-Proxy] Framework error handler installing...
[PI-Proxy] Framework error handler installed
```

Key points:

* This is the **same runtime** as on Cloudflare, but now running on:

  * `http://localhost:3100/proxy?url=https%3A%2F%2Fwww.njtransit.com%2Ftrain-to%3Forigin%3D...`
* We also see the same `<link rel=preload>` warnings and some third-party pixels failing (e.g. HubSpot GIF 400), which is normal and not fatal.

### 4.2 NJTransit app behavior

Again we see:

```text
[nuxt] error caught during app initialization Error: Context conflict
    at r (proxy?url=https%3A%2F%2Fwww.njtransit.com%2F_nuxt%2FBHrqiTBk.js:20:39026)
    at Object.set (proxy?url=https%3A%2F%2Fwww.njtransit.com%2F_nuxt%2FBHrqiTBk.js:20:39410)
```

So NJTransit’s Nuxt stack is complaining in **both** environments. This feels like:

* Either a genuine bug in their app when loaded under some conditions, or
* A side-effect of our proxy environment (e.g. something about `window`, context reuse, or re-mounting).

However, subjectively, **the localhost version “looks right”** in the browser — which matches your experience: the train page appears and is usable enough.

### 4.3 Differences vs Cloudflare, from the logs

Comparing the two:

* **Local log:**

  * Only NJTransit page console noise.
  * No preview shell logs (`[preview]`), because you’re likely opening the proxied NJT URL directly.
  * The Nuxt context error shows up but doesn’t kill your mental model: the page still “looks fine”.

* **Cloudflare log:**

  * Mixed logs from:

    * Preview shell
    * Player iframe
    * Pulseinsights.com host page
    * NJTransit host page
  * Widget fallback logic firing repeatedly:

    * `widget fallback waiting for widget`
    * `scheduleWidgetFallbackRetry`
  * So the preview experience doesn’t stabilize — which looks broken even if the underlying NJT page loads somewhat.

---

## 5. What’s actually going on (synthesis)

Putting it all together:

1. **Both environments successfully proxy NJTransit.**

   * Same runtime hooks, same Nuxt app, same `Context conflict` error.
   * You can see the NJTransit HTML being processed in both logs.

2. **The “Cloudflare → pulseinsights.com” behavior you’re seeing is primarily driven by preview configuration + preserved logs.**

   * In `njt-06-95abb1ec.log` we clearly see:

     * `Host page: https://www.pulseinsights.com/agents`
     * Followed by proxied fetch:

       * `proxy?url=https%3A%2F%2Fwww.pulseinsights.com%2Fagents`
   * That’s not the site “redirecting” to pulseinsights.com; it’s the preview picking that URL as the host page for that run.
   * Later, in the same log, you *also* load the NJTransit train page via the proxy.

3. **The Cloudflare preview is more fragile from the user’s perspective.**

   * Because:

     * It’s layering:

       * Preview shell (overlay logic + widget fallback)
       * Player iframe
       * Proxy runtime
       * NJTransit’s own app
     * The widget fallback retries never settle, so the UI “feels” broken.
   * Meanwhile, on localhost, you’re often just hitting the proxied NJTransit page directly, bypassing the extra complexity of the preview shell.

4. **DevTools “Preserve log” makes the difference harder to see.**

   * A single export contains:

     * Pulse Agents run(s)
     * NJ Transit run(s)
     * Possibly some local-only attempts
   * So from the raw file, it’s easy to conflate the distinct phases.

---

## 6. Where the new Worker code fits into this story

The Worker code I gave you is about **how Cloudflare talks to NJTransit at the network layer**:

* Spoofs a normal browser User-Agent and headers.
* Forwards `X-Forwarded-For` with the client IP.
* Avoids looking like a backend or bot.
* Lets you detect / block suspicious redirects (e.g. if NJTransit’s CDN ever does decide to send you to `pulseinsights.com` via an HTTP 30x).

In other words:

* **This doc explains what the logs show happening in the browser.**
* **The Worker changes address what happens at the edge when we fetch the upstream page.**

Those two layers combined should make:

* The preview behavior more predictable.
* Any “mystery redirect” easier to reason about (you’d see it explicitly as a 30x, not as a vague feeling that “Cloudflare sends me to Pulse”).

---

## 7. Takeaways

* Localhost and Cloudflare are both successfully running the same proxy runtime, but the **Cloudflare preview mixes multiple runs and host pages** (Pulse + NJT).
* The console logs clearly show:

  * Preview shell choosing `www.pulseinsights.com/agents` as host in some runs.
  * The same Nuxt context error appearing for NJT in both environments.
* The new Worker is the right direction for making upstream requests behave more like a real browser and less like a “backend integration”.