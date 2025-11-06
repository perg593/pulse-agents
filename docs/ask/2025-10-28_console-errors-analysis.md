# Console Errors Analysis - Preview Application

**Date:** 2025-10-28  
**Context:** Preview application running at `localhost:8000` with survey player iframe

## Summary

The console shows multiple categories of issues:
1. **Widget geometry detection failures** - Primary issue affecting overlay placement
2. **Cross-origin security restrictions** - Blocking background frame access
3. **Survey loading failures** - 403 Forbidden errors from survey API
4. **Third-party service warnings** - External dependencies (Google, Meta, Framer)
5. **Iframe sandbox security warnings** - Browser security notifications

---

## 1. Widget Geometry Detection Failures

### Error Messages
```
[preview] Widget geometry unavailable; approximating overlay placement (CENTER).
[preview] geometry update failed after max retries
[preview] Widget geometry not detected after present. The survey 8066 may rely on inline placement or is blocked by https://thesociablesociety.com/creator-management-services/.
```

### Root Cause Analysis

The preview system relies on **postMessage communication** between the main preview window and the survey player iframe to receive widget geometry information. The geometry detection flow:

1. **Player iframe** (`player.html`) detects widget visibility and calculates bounds
2. **Player sends geometry** via `postMessage` with `widget-geometry` status
3. **Preview receives** geometry in `updatePlayerWidgetGeometry()` function
4. **Preview applies** geometry to position overlay container

**Failure points:**

```2943:3002:preview/basic/preview.js
function updatePlayerWidgetGeometry(message) {
  // If iframe is not ready, queue the update
  if (!iframePositioned || !playerFrameEl) {
    if (pendingGeometryUpdates.length < 5) {
      pendingGeometryUpdates.push(message);
      console.debug('[preview] geometry update queued (iframe not ready)', {
        queued: pendingGeometryUpdates.length,
        message
      });
    } else {
      console.warn('[preview] geometry update queue full, dropping update', message);
    }
    return;
  }

  const incomingMode = message?.mode === 'inline' ? 'inline' : 'overlay';
  if (incomingMode !== playerMode) {
    playerMode = incomingMode;
  }
  const placement = normalizePlacementToken(message?.placement);
  if (placement) {
    overlayPlacementHint = placement;
  }
  playerViewportSize = normalizeViewport(message?.viewport);
  const rect = normalizeWidgetRect(message?.rect);
  const hadRect = !!playerWidgetRect;
  const wasInFallback = overlayFallbackActive;
  
  // Validate geometry: if rect is invalid or missing, schedule retry
  if (!rect && playerMode === 'overlay' && !hadRect) {
    // No geometry received, schedule retry if we haven't exceeded max retries
    if (geometryRetryCount < MAX_GEOMETRY_RETRIES) {
      const retryDelay = GEOMETRY_RETRY_DELAYS[geometryRetryCount] || 2000;
      geometryRetryCount++;
      console.debug('[preview] geometry update missing rect, scheduling retry', {
        attempt: geometryRetryCount,
        delay: retryDelay,
        message
      });
      
      if (geometryRetryTimeout) {
        clearTimeout(geometryRetryTimeout);
      }
      geometryRetryTimeout = window.setTimeout(() => {
        geometryRetryTimeout = null;
        // Request geometry refresh from player
        if (surveyBridge && typeof surveyBridge.sendTrigger === 'function') {
          surveyBridge.sendTrigger('ping');
        }
        // Also retry processing this message
        updatePlayerWidgetGeometry(message);
      }, retryDelay);
      return;
    } else {
      console.warn('[preview] geometry update failed after max retries', {
        retries: geometryRetryCount,
        message
      });
      geometryRetryCount = 0;
    }
  }
```

**Possible reasons for failure:**

1. **Survey widget not loading** - The survey (8066) may not be loading in the player iframe
2. **Widget detection timing** - Widget may load after geometry detection timeout (4-6 seconds)
3. **Survey uses inline placement** - Some surveys inject directly into page DOM rather than overlay
4. **Content Security Policy** - CSP may block widget injection
5. **Cross-origin restrictions** - Player iframe may not be able to detect widget in proxied background frame

### Fallback Behavior

When geometry detection fails, the system falls back to approximate placement:

```2829:2851:preview/basic/preview.js
  if (!overlayFallbackActive && !overlayFallbackLogged) {
    addLog(
      `Widget geometry unavailable; approximating overlay placement (${placement}).`,
      'warn'
    );
    overlayFallbackLogged = true;
  }
  overlayFallbackActive = true;

  overlayContainer.style.position = 'fixed';
  overlayContainer.style.visibility = 'visible';
  overlayContainer.style.opacity = '1';
  overlayContainer.style.pointerEvents = 'auto';
  overlayContainer.style.overflow = 'hidden';
  overlayContainer.style.clipPath = '';
  overlayContainer.style.webkitClipPath = '';
  overlayContainer.style.width = `${metrics.width}px`;
  overlayContainer.style.height = `${metrics.height}px`;
  overlayContainer.style.top = metrics.top != null ? `${metrics.top}px` : '';
  overlayContainer.style.left = metrics.left != null ? `${metrics.left}px` : '';
  overlayContainer.style.right = metrics.right != null ? `${metrics.right}px` : '';
  overlayContainer.style.bottom = metrics.bottom != null ? `${metrics.bottom}px` : '';
  overlayContainer.dataset.fallbackPlacement = placement;
```

---

## 2. Cross-Origin Frame Access Errors

### Error Message
```
[preview] Background document not accessible SecurityError: Failed to read a named property 'document' from 'Window': Blocked a frame with origin "http://localhost:8000" from accessing a cross-origin frame.
```

### Root Cause

The preview system loads the host page in an iframe (`background-frame`). When the host page is from a different origin (even when proxied), browser security policies prevent accessing the iframe's `contentDocument`:

```615:624:preview/basic/preview.js
function getBackgroundDocument() {
  const frame = siteRoot.querySelector('iframe.background-frame');
  if (!frame) return null;
  try {
    return frame.contentDocument || frame.contentWindow?.document || null;
  } catch (error) {
    console.warn('[preview] Background document not accessible', error);
    return null;
  }
}
```

This function is called when applying themes to the background frame:

```626:640:preview/basic/preview.js
function applyThemeToBackgroundFrame(href) {
  const doc = getBackgroundDocument();
  if (!doc || !doc.head) return;
  let link = doc.getElementById('preview-theme-css');
  if (link && link.parentNode) {
    link.parentNode.removeChild(link);
  }
  if (!href) return;
  link = doc.createElement('link');
  link.rel = 'stylesheet';
  const resolvedHref = resolveThemeHref(href);
  link.href = resolvedHref;
  link.id = 'preview-theme-css';
  doc.head.appendChild(link);
}
```

**Impact:** Theme application to background frame fails silently. The error is caught and logged, but theme styles won't be applied to the proxied background page.

**Why this happens:**
- Background frame is loaded via proxy (`buildProxySrc()`)
- Even with proxy, browser treats it as cross-origin if URL differs
- Same-origin policy blocks `contentDocument` access

---

## 3. Survey Loading Failures (403 Forbidden)

### Error Messages
```
Failed to load resource: the server responded with a status of 403 (Forbidden)
survey.pulseinsights.com/surveys/8066?...&callback=window.PulseInsightsObject.jsonpCallbacks.request_1
survey.pulseinsights.com/surveys/8066?...&callback=window.PulseInsightsObject.jsonpCallbacks.request_2
```

### Analysis

The survey player is attempting to load survey data via JSONP from `survey.pulseinsights.com`, but receiving 403 Forbidden responses.

**Possible causes:**

1. **Authentication/Authorization** - Survey 8066 may require specific account permissions
2. **CORS/CSP restrictions** - Server may block requests from `localhost:8000`
3. **Account mismatch** - URL shows `account=PI-49948395` but earlier logs show `PI-81598442`
4. **Survey access restrictions** - Survey may be disabled, archived, or restricted to specific domains
5. **Rate limiting** - Multiple rapid requests may trigger rate limiting

**Impact:** Survey widget never loads, causing geometry detection to fail.

---

## 4. Widget Detection Timeout

### Error Message
```
[preview] Survey 8066 widget not detected yet (2s check, source: message).
```

### Analysis

The system periodically checks for widget presence:

```2726:2735:preview/basic/preview.js
    case 'widget-check':
      console.log('[preview] survey widget check', message);
      if (message.delay >= 2000 && !message.present) {
        addLog(
          `Survey ${surveyId} widget not detected yet (2s check, source: ${source || 'unknown'}).`,
          'warn'
        );
      }
      if (message.present && message.delay === 0) {
        addLog(`Survey ${surveyId} widget detected (source: ${source || 'unknown'}).`);
      }
      break;
```

After 2 seconds, the widget still hasn't been detected. This aligns with the 403 errors preventing survey load.

---

## 5. Third-Party Service Warnings

### Google Tag Manager
```
Error: Google tag G-VVMENJXSY4 loaded before Consent Mode update. Please review and resolve Google Consent Mode sequencing.
```

**Impact:** Low - External site issue, not preview system

### Meta Pixel
```
[Meta pixel] 1584245765172382 is unavailable on this website due to it's traffic permission settings.
```

**Impact:** Low - External site configuration issue

### React Hydration Errors (Framer)
```
Caught a recoverable error. The site is still functional, but might have some UI flickering or degraded page load performance.
Error: Minified React error #425
Error: Minified React error #422
```

**Impact:** Low - External site (Framer) SSR/hydration mismatch, not preview system

---

## 6. Iframe Sandbox Security Warnings

### Warning Message
```
An iframe which has both allow-scripts and allow-same-origin for its sandbox attribute can escape its sandboxing.
```

### Analysis

This is a **browser security warning**, not an error. It appears when an iframe has both:
- `allow-scripts` - Allows JavaScript execution
- `allow-same-origin` - Allows same-origin access

Together, these allow the iframe to bypass sandbox restrictions. This is expected behavior for the survey player iframe, which needs both capabilities.

**Impact:** None - Informational browser warning

---

## Recommendations

### Immediate Actions

1. **Investigate survey 403 errors**
   - Verify survey 8066 is accessible for account `PI-49948395`
   - Check survey status (active/archived/disabled)
   - Verify account permissions
   - Test with different survey ID

2. **Improve geometry detection resilience**
   - Increase timeout for widget detection (currently 4-6 seconds)
   - Add better error messages indicating why geometry failed
   - Consider polling widget detection more aggressively

3. **Handle cross-origin theme application**
   - Use postMessage to inject styles into background frame instead of direct DOM access
   - Or accept that proxied frames can't have themes applied directly

### Code Improvements

1. **Better error context**
   - Include survey ID, account, and URL in geometry failure messages
   - Log survey API response status codes

2. **Fallback placement improvements**
   - Use viewport size hints from player to improve fallback placement
   - Consider user-configurable fallback placement

3. **Cross-origin handling**
   - Detect cross-origin frames and skip theme application gracefully
   - Document limitation in UI/logs

---

## Related Files

- `preview/basic/preview.js` - Main preview logic
- `preview/app/survey/player.js` - Survey player iframe
- `preview/app/survey/bridge.js` - Communication bridge
- `preview/app/survey/player.html` - Player iframe HTML

---

## Next Steps

1. Test with a known-working survey ID
2. Verify account permissions for survey 8066
3. Check survey API logs for 403 error details
4. Consider implementing postMessage-based theme injection for cross-origin frames

