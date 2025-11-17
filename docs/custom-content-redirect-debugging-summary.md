# Custom Content Redirect Functionality - Debugging Summary

## Overview

This document summarizes the implementation and debugging of custom content question features, including link handling (working) and auto-redirect functionality (still debugging).

## Working Features

### 1. Custom Content Link Click Handling ✅

**Status**: Fully functional

**Implementation**:
- **File**: `preview/app/survey/player.js`
- **Functions**:
  - `setupCustomContentLinkHandling()`: Sets up event delegation for link clicks
  - `attachLinkHandlers(container)`: Attaches click listener to widget container
  - `handleCustomContentLinkClick(event)`: Intercepts clicks on `<a>` tags within `._pi_question_custom_content_question` elements

**How it works**:
1. Event delegation on `#_pi_surveyWidgetContainer` catches all link clicks
2. Checks if link is within a custom content question
3. Prevents default behavior
4. Sends `link-click` message to parent bridge via `postLegacyMessage()`
5. Bridge receives message and opens link using `handleLinkClick()`:
   - `target="_blank"`: Uses `window.open(href, '_blank', 'noopener')`
   - Default/`_self`: Uses `window.location.href` for same-origin, `window.open(href, '_self')` for cross-origin

**Message Flow**:
```
Player iframe → postLegacyMessage({ type: 'link-click', href, target }) 
→ Bridge receives → handleLinkClick() → Navigates parent window
```

**Files Modified**:
- `preview/app/survey/player.js`: Link click interception
- `preview/app/survey/bridge.js`: `handleLinkClick()` function and message handlers

## In Progress: Auto-Redirect Functionality

### Problem Statement

Custom content questions can have auto-redirect enabled with:
- `autoredirect_enabled`: `'t'` (enabled) or `'f'` (disabled)
- `autoredirect_delay`: Delay in seconds (e.g., `'5'`)
- `autoredirect_url`: URL to redirect to (e.g., `'https://www.njtransit.com'`)

**Expected Behavior**: After the delay, redirect the main browser window to the specified URL.

**Current Behavior**: Redirect happens, but opens in the survey widget iframe instead of the main browser window.

### Configuration Source

The redirect configuration is stored in `window.PulseInsightsObject.survey.questions[]` array:
```javascript
{
  question_type: 'custom_content_question',
  autoredirect_enabled: 't',
  autoredirect_delay: '5',
  autoredirect_url: 'https://www.njtransit.com'
}
```

### Implementation Attempts

#### Attempt 1: Timer-Based Redirect with Message Passing

**Approach**: Create timer in player iframe, send message to bridge when timer expires.

**Implementation**:
- `setupCustomContentRedirectTimers()`: Detects custom content questions and starts timers
- `detectAndStartRedirectTimers()`: Finds questions with `autoredirect_enabled === 't'` and starts timers
- `startRedirectTimer()`: Uses `setTimeout()` to send redirect message after delay
- `handleRedirect()` in bridge: Receives message and navigates parent window

**Result**: Timer starts correctly (confirmed by logs), but timer callback never executes. No logs appear when timer should expire.

**Evidence**:
- `[player] redirect timer started` appears in console
- `[player] redirect timer expired - SENDING MESSAGE` never appears
- `localStorage` entries (`pi_redirect_log`, `pi_redirect_sent`) remain null
- Alert added to timer callback never appears

**Conclusion**: Timer callback is not executing, suggesting surveys.js is handling redirect before our timer fires.

#### Attempt 2: Intercept Location Navigation Methods

**Approach**: Override `location.replace()`, `location.assign()`, and `location.href` setter to catch redirects from surveys.js.

**Implementation**:
- Early interceptor in `setupLocationInterceptorEarly()` (runs immediately on script load)
- Overrides `location.replace()` and `location.assign()`
- Attempts to override `window.location` property setter
- Fallback to `Location.prototype.href` setter override

**Code Location**: `preview/app/survey/player.js`, lines 30-214

**Result**: No intercept logs appear, suggesting surveys.js uses a method we're not catching.

#### Attempt 3: Analyze surveys.js Behavior

**Finding**: surveys.js uses `window.location = redirect_url` (direct assignment).

**Evidence**: From surveys.js minified code:
```javascript
"t"===this.question.autoredirect_enabled&&null!=this.question.autoredirect_url&&null!=this.question.autoredirect_delay&&(redirect_url=this.question.autoredirect_url,setTimeout(function(){return window.location=redirect_url},1e3*this.question.autoredirect_delay))
```

**Attempted Fix**: Added interception for `window.location = url` assignments:
- Try to override `window.location` property with getter/setter
- Fallback to `Location.prototype.href` setter

**Result**: Still no intercept logs. `window.location` property is likely not configurable in browsers.

#### Attempt 4: Polling Watcher and beforeunload Listener

**Approach**: Monitor `location.href` changes using polling and `beforeunload` event.

**Implementation**:
- Polling watcher checks `location.href` every 50ms
- `beforeunload` listener to detect navigation attempts
- Attempts to prevent navigation and send message instead

**Result**: Not effective - by the time we detect the change, navigation has already started.

#### Attempt 5: Fix Message Origin and Bridge Acceptance

**Problem**: Early interceptor was sending messages with origin `'*'`, but bridge rejects these.

**Fix**:
- Changed to use `window.location.origin` when sending messages
- Updated bridge message handlers to accept messages even if `playerOrigin` not set yet

**Code Changes**:
- `preview/app/survey/player.js`: Use `currentOrigin` instead of `'*'`
- `preview/app/survey/bridge.js`: Changed origin check from `event.origin !== playerOrigin` to `event.origin && playerOrigin && event.origin !== playerOrigin`

**Result**: Messages should now be accepted, but still no intercept logs appear.

### Current State

**What's Working**:
- Timer detection and start: ✅ Confirmed working (logs show timer started)
- Timer cleanup: ✅ Implemented (on dismiss, page unload, via message)
- Link click handling: ✅ Fully functional

**What's Not Working**:
- Timer callback execution: ❌ Never fires (no logs, no localStorage, no alert)
- Location interception: ❌ No intercept logs appear
- Redirect navigation: ❌ Opens in iframe instead of main window

**Hypothesis**: surveys.js is executing `window.location = redirect_url` before our interceptors can catch it, or the assignment bypasses our interceptors entirely.

### Technical Challenges

1. **`window.location` is not configurable**: Cannot override `window.location` property directly in most browsers
2. **`Location.prototype.href` may not be configurable**: Browser security restrictions prevent overriding
3. **Timing issue**: surveys.js redirect happens before our timer callback executes
4. **surveys.js is external**: Cannot modify surveys.js directly, must intercept its behavior

### Files Modified

1. **`preview/app/survey/player.js`**:
   - Link click handling functions (working)
   - Redirect timer setup functions (timer starts but callback doesn't execute)
   - Location interception attempts (not catching redirects)
   - Early interceptor setup (runs immediately on script load)

2. **`preview/app/survey/bridge.js`**:
   - `handleLinkClick()` function (working)
   - `handleRedirect()` function (receives messages but redirect still opens in iframe)
   - Message handlers for both legacy and protocol bridges
   - Origin checking logic updated

### Debug Logging Added

**Player.js**:
- `[player] setupCustomContentRedirectTimers called`
- `[player] detectAndStartRedirectTimers called`
- `[player] redirect timer started`
- `[player] redirect timer expired - SENDING MESSAGE` (never appears)
- `[player] EARLY INTERCEPT location.replace/assign/window.location =` (never appears)

**Bridge.js**:
- `[bridge] RECEIVED redirect message` (never appears)
- `[bridge] handleRedirect CALLED` (never appears)
- `[bridge] redirect using top window` (never appears)

### Next Steps to Investigate

1. **Verify surveys.js execution timing**: Check if surveys.js redirect happens synchronously or asynchronously
2. **Try Proxy approach**: Use Proxy to intercept location property access (may not work due to browser restrictions)
3. **Check iframe sandbox attributes**: Verify if sandbox restrictions prevent location changes
4. **Alternative approach**: Instead of intercepting, prevent surveys.js from running its redirect by modifying PulseInsightsObject before surveys.js reads it
5. **Check browser console for errors**: Look for any errors that might prevent interceptors from working
6. **Test in different browsers**: Verify if behavior is consistent across browsers
7. **Consider iframe src manipulation**: If surveys.js redirects the iframe, we could detect the iframe src change and redirect the parent

### Code References

**Link Handling (Working)**:
- `preview/app/survey/player.js`: Lines 1547-1691
- `preview/app/survey/bridge.js`: Lines 24-86

**Redirect Timer Setup**:
- `preview/app/survey/player.js`: Lines 1844-1909 (setup functions)
- `preview/app/survey/player.js`: Lines 1997-2049 (timer functions)

**Location Interception**:
- `preview/app/survey/player.js`: Lines 30-214 (early interceptor)
- `preview/app/survey/player.js`: Lines 1699-1842 (later interceptor setup)

**Bridge Redirect Handler**:
- `preview/app/survey/bridge.js`: Lines 88-180

### Git History

All changes are on branch: `feature/custom-content-link-handling`

Key commits:
- Link click handling implementation
- Redirect timer setup
- Location interception attempts
- Message origin fixes
- Debug logging additions

### Testing Observations

**Console Output When Redirect Happens**:
```
[player] redirect timer started {questionId: 27161, url: 'https://www.njtransit.com', delay: 5000}
... (5 seconds pass) ...
www.njtransit.com loads in iframe
```

**Missing Logs**:
- No timer expiration logs
- No intercept logs
- No bridge receive logs
- No redirect handler logs

**localStorage Check**:
- `localStorage.getItem('pi_redirect_log')`: null
- `localStorage.getItem('pi_redirect_sent')`: null
- `localStorage.getItem('pi_redirect_error')`: null

This confirms the timer callback never executes.

### Conclusion

The redirect functionality is partially implemented but not working as expected. The timer starts correctly, but surveys.js appears to handle the redirect before our timer callback executes, or uses a method we cannot intercept. The link click handling works perfectly and can serve as a reference for the expected message-passing pattern.

