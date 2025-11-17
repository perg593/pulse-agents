# Fix: Custom Content Link Handling & Auto-Redirect Functionality

## Summary

This PR implements comprehensive custom content question handling for Pulse widget surveys, including:
1. **Link click handling** - Intercepts clicks on links within custom content questions and navigates the main browser window
2. **Auto-redirect functionality** - Prevents surveys.js from redirecting the iframe and instead redirects the main browser window
3. **Control rail hiding** - Hides the preview control rail when `?present=XXXX` URL parameter is active
4. **Flash prevention** - Eliminates visual flash of control rail before it's hidden

## Problem

### Custom Content Link Clicks
Links within custom content questions in iframes were navigating the iframe instead of the main browser window, breaking user expectations.

### Custom Content Auto-Redirect
Custom content questions with `autoredirect_enabled` were redirecting the iframe instead of the main browser window. The external `surveys.js` script executed `window.location = redirect_url` before our timer callback could fire, and this action was uninterceptable.

### Control Rail Visibility
When using the `?present=XXXX` URL parameter to present surveys in a clean view, the control rail would briefly flash before being hidden, creating a poor user experience.

## Solution

### 1. Link Click Handling
- Intercepts click events on `<a>` tags within custom content questions
- Validates URLs for security (prevents dangerous schemes like `javascript:`, `data:`, etc.)
- Sends `link-click` messages to the bridge via `postMessage`
- Bridge navigates the main browser window using the same pattern as other navigation

### 2. Auto-Redirect Functionality
Uses a **prevention approach**:
1. **Disable autoredirect in PulseInsightsObject**: Before surveys.js reads config, we modify `autoredirect_enabled` to `'f'` and set `_autoredirect_disabled_by_player` flag
2. **Set up our own timer**: Detect custom content questions and set up redirect timer that sends message to bridge
3. **Bridge handles navigation**: Bridge receives redirect message and navigates main browser window using same pattern as link clicks
4. **Prevent duplicates**: Added `pendingRedirectTimers` Set to prevent race conditions

### 3. Control Rail Hiding
- Detects `?present=XXXX` URL parameter on page load
- Hides control rail via JavaScript when parameter is present
- Sets `data-present-mode` attribute for CSS targeting

### 4. Flash Prevention
- Adds inline `<script>` in HTML `<head>` that runs synchronously before DOM content loads
- Checks for `present` parameter immediately and injects CSS to hide control rail
- Prevents Flash of Unstyled Content (FOUC) by hiding rail before browser renders it

## Changes Made

### Phase 1: Core Functionality
- Added link click interception in `player.js`
- Added link click handler in `bridge.js`
- Added auto-redirect timer detection and setup
- Added redirect handler in `bridge.js`

### Phase 2: Critical Cleanup
- Removed DEBUG-prefixed console logs
- Simplified `handleRedirect()` to match `handleLinkClick()` pattern
- Removed complex `window.top` logic
- Used same navigation methods as link handler

### Phase 3: Code Cleanup
- Removed ~200 lines of unused location interceptor code
- Added JSDoc comments to all new functions
- Added early PulseInsightsObject interceptor

### Phase 4: Code Quality
- Normalized question ID comparison
- Extracted magic values to constants
- Reduced console logging verbosity
- Added security validation for dangerous URL schemes

### Phase 5: UI Improvements
- Added control rail hiding functionality
- Implemented flash prevention mechanism
- Added test HTML file for auto-redirect functionality

## Files Changed

### Core Implementation
- `preview/app/survey/player.js` - Main implementation
  - Added `setupCustomContentLinkHandling()`
  - Added `attachLinkHandlers(container)`
  - Added `handleCustomContentLinkClick(event)`
  - Added `disableAutoredirectInPulseInsightsObject()`
  - Added `detectAndStartRedirectTimers()`
  - Added `startRedirectTimer()`
  - Removed unused location interceptor code
  - Added JSDoc documentation
  - Extracted constants

- `preview/app/survey/bridge.js` - Message handlers
  - Added `handleLinkClick()` - Handles link click messages
  - Simplified `handleRedirect()` to match `handleLinkClick()` pattern
  - Removed excessive debug logging
  - Added security validation for URLs

### UI & Preview
- `index.html` - Main preview HTML
  - Added inline script in `<head>` to prevent control rail flash
  - Script runs synchronously before DOM content loads

- `preview/basic/preview.js` - Preview application logic
  - Added `hideControlRail()` function
  - Calls `hideControlRail()` when `presentSurveyId` is detected
  - Sets `data-present-mode` attribute for CSS targeting

### Testing & Documentation
- `preview/widgets/docked_widget/custom_content_autoredirect.html` - Test HTML file for auto-redirect functionality
- `PR_DESCRIPTION.md` - Original PR description (auto-redirect focus)
- `docs/review/custom-content-redirect-code-review.md` - Code review document
- `docs/custom-content-redirect-debugging-summary.md` - Debugging summary
- `docs/architecture/data-model.md` - Updated with player runtime data models

## Testing

### Link Click Handling
✅ Link clicks navigate main browser window  
✅ Cross-origin links work correctly  
✅ Same-origin links work correctly  
✅ Dangerous URL schemes are blocked  
✅ Multiple links in same question work  
✅ Links work after survey switching  

### Auto-Redirect Functionality
✅ Auto-redirect works correctly  
✅ Redirects main browser window (not iframe)  
✅ Timer cleanup works  
✅ No duplicate timers  
✅ Cross-origin and same-origin redirects work  
✅ Works with various delay values  

### Control Rail Hiding
✅ Control rail hides when `?present=XXXX` is present  
✅ Control rail shows normally without parameter  
✅ No flash of control rail on page load  
✅ Works with valid 4-digit survey IDs  
✅ Ignores invalid parameter values  

### Integration Testing
✅ Link clicks and auto-redirect work together  
✅ No conflicts between features  
✅ Survey switching works correctly  
✅ Multiple custom content questions work  

## Code Metrics

- **Lines Added**: ~1,863 insertions
- **Lines Removed**: ~1 deletion
- **Net Change**: +1,862 lines
- **Files Changed**: 9 files
- **Functions Added**: 7 new functions with JSDoc
- **Constants Added**: 6 constants

## Technical Details

### Key Functions

#### Link Handling
1. `setupCustomContentLinkHandling()` - Sets up link click interception
2. `attachLinkHandlers(container)` - Attaches handlers to container
3. `handleCustomContentLinkClick(event)` - Handles link click events
4. `handleLinkClick()` - Bridge handler for link click messages

#### Auto-Redirect
1. `disableAutoredirectInPulseInsightsObject()` - Modifies PulseInsightsObject to disable autoredirect
2. `detectAndStartRedirectTimers()` - Detects questions and starts timers
3. `startRedirectTimer()` - Sets up timer that sends redirect message
4. `handleRedirect()` - Simplified to match `handleLinkClick()` pattern

#### UI
1. `hideControlRail()` - Hides control rail when present parameter is active

### Constants Added

```javascript
const AUTOREDIRECT_ENABLED = 't';
const AUTOREDIRECT_DISABLED = 'f';
const QUESTION_TYPE_CUSTOM_CONTENT = 'custom_content_question';
const DEFAULT_REDIRECT_DELAY_MS = 2000;
const PULSEINSIGHTS_CHECK_INTERVAL_MS = 50;
const PULSEINSIGHTS_CHECK_TIMEOUT_MS = 10000;
```

### Security Features

- URL scheme validation prevents dangerous schemes:
  - `javascript:` - Prevents XSS attacks
  - `data:` - Prevents data URI navigation
  - `vbscript:` - Prevents VBScript execution
  - Other non-HTTP(S) schemes

### Performance Optimizations

- Early detection of `present` parameter prevents render flash
- Inline script in `<head>` executes before DOM content
- Efficient event delegation for link clicks
- Timer cleanup prevents memory leaks

## Breaking Changes

None - All changes maintain backward compatibility.

## Migration Guide

No migration needed - this is a feature addition and bug fix.

## Checklist

- [x] Code follows project conventions
- [x] All functions have JSDoc comments
- [x] Proper error handling
- [x] No hardcoded values (uses constants)
- [x] Proper cleanup of timers
- [x] Security validation for URLs
- [x] Tested functionality
- [x] No linter errors
- [x] Code review completed
- [x] Flash prevention tested
- [x] Control rail hiding tested
- [x] Link click handling tested
- [x] Auto-redirect tested

## Related Issues

- Fixes custom content link navigation
- Fixes custom content auto-redirect behavior
- Improves preview UI when using `?present` parameter

## Screenshots / Demo

Test the features:
- **Link clicks**: Use `preview/widgets/docked_widget/custom_content_autoredirect.html`
- **Auto-redirect**: Use custom content question with `autoredirect_enabled=true`
- **Control rail hiding**: Visit `index.html?present=7990`

## Notes

- The inline script in `index.html` is intentionally minimal and runs synchronously
- Flash prevention requires the script to be in `<head>` before any content
- Control rail hiding works with both JavaScript and CSS (via `data-present-mode` attribute)

