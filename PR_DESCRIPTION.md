# Fix: Custom Content Auto-Redirect Functionality

## Summary

Fixes auto-redirect functionality for custom content questions. Prevents surveys.js from redirecting the iframe and instead redirects the main browser window, matching link click behavior.

## Problem

Custom content questions with `autoredirect_enabled` were redirecting the iframe instead of the main browser window. The external `surveys.js` script executed `window.location = redirect_url` before our timer callback could fire, and this action was uninterceptable.

## Solution

Uses a **prevention approach**:

1. **Disable autoredirect in PulseInsightsObject**: Before surveys.js reads config, we modify `autoredirect_enabled` to `'f'` and set `_autoredirect_disabled_by_player` flag
2. **Set up our own timer**: Detect custom content questions and set up redirect timer that sends message to bridge
3. **Bridge handles navigation**: Bridge receives redirect message and navigates main browser window using same pattern as link clicks
4. **Prevent duplicates**: Added `pendingRedirectTimers` Set to prevent race conditions

## Changes Made

### Phase 1: Critical Cleanup
- Removed DEBUG-prefixed console logs
- Simplified `handleRedirect()` to match `handleLinkClick()` pattern
- Removed complex `window.top` logic
- Used same navigation methods as link handler

### Phase 2: Code Cleanup
- Removed ~200 lines of unused location interceptor code
- Added JSDoc comments to all new functions
- Added early PulseInsightsObject interceptor

### Phase 3: Code Quality
- Normalized question ID comparison
- Extracted magic values to constants
- Reduced console logging verbosity

## Files Changed

- `preview/app/survey/player.js` - Main implementation
  - Added `disableAutoredirectInPulseInsightsObject()`
  - Added `detectAndStartRedirectTimers()`
  - Added `startRedirectTimer()`
  - Removed unused location interceptor code
  - Added JSDoc documentation
  - Extracted constants

- `preview/app/survey/bridge.js` - Redirect handler
  - Simplified `handleRedirect()` to match `handleLinkClick()`
  - Removed excessive debug logging

- `docs/review/custom-content-redirect-code-review.md` - Code review document

## Testing

✅ Auto-redirect works correctly  
✅ Link clicks still work (no regression)  
✅ Timer cleanup works  
✅ No duplicate timers  
✅ Cross-origin and same-origin redirects work  

## Code Metrics

- **Lines Added**: ~150 insertions
- **Lines Removed**: ~444 deletions
- **Net Change**: -294 lines (code reduction)
- **Functions Added**: 4 new functions with JSDoc
- **Constants Added**: 6 constants

## Technical Details

### Key Functions

1. `disableAutoredirectInPulseInsightsObject()` - Modifies PulseInsightsObject to disable autoredirect
2. `detectAndStartRedirectTimers()` - Detects questions and starts timers
3. `startRedirectTimer()` - Sets up timer that sends redirect message
4. `handleRedirect()` - Simplified to match `handleLinkClick()` pattern

### Constants Added

```javascript
const AUTOREDIRECT_ENABLED = 't';
const AUTOREDIRECT_DISABLED = 'f';
const QUESTION_TYPE_CUSTOM_CONTENT = 'custom_content_question';
const DEFAULT_REDIRECT_DELAY_MS = 2000;
const PULSEINSIGHTS_CHECK_INTERVAL_MS = 50;
const PULSEINSIGHTS_CHECK_TIMEOUT_MS = 10000;
```

## Breaking Changes

None - Bug fix maintaining backward compatibility.

## Checklist

- [x] Code follows project conventions
- [x] All functions have JSDoc comments
- [x] Proper error handling
- [x] No hardcoded values (uses constants)
- [x] Proper cleanup of timers
- [x] Tested functionality
- [x] No linter errors
- [x] Code review completed
