# Security Fixes: Origin Validation

## Issues Fixed

### Issue 1: Security Bypass - Origin Validation Incomplete
**Location:** `preview/app/survey/bridge.js` line 328 (Legacy Bridge)

**Problem:**
- Original code: `if (event.origin && playerOrigin && event.origin !== playerOrigin) return;`
- When `playerOrigin` was `'*'` (fallback), the validation was incomplete
- The check would reject messages when `event.origin !== '*'`, but `'*'` was used as an insecure fallback that could accept messages from any origin

**Fix:**
- Changed fallback from `'*'` to `null`
- Added explicit check to reject messages when `playerOrigin` is `null` or `'*'`
- Only accept messages when `playerOrigin` is a valid origin string and matches exactly

### Issue 2: Security Flaw - Origin Validation Bypass
**Location:** `preview/app/survey/bridge.js` line 627 (Protocol Bridge)

**Problem:**
- Same issue as Issue 1, but in the Protocol Bridge's legacy message handler
- Original code: `if (event.origin && playerOrigin && event.origin !== playerOrigin) return;`
- Same vulnerability with `'*'` fallback

**Fix:**
- Same fix as Issue 1 - changed fallback to `null` and added explicit validation

## Changes Made

### 1. Changed Fallback Values
**Before:**
```javascript
let playerOrigin = (() => {
  try {
    return typeof window !== 'undefined' && window.location
      ? window.location.origin || '*'
      : '*';
  } catch (_error) {
    return '*';
  }
})();
```

**After:**
```javascript
let playerOrigin = (() => {
  try {
    // Security: Never use '*' as fallback - it's insecure
    // Return null if we can't determine origin, which will cause rejection until origin is set
    return typeof window !== 'undefined' && window.location
      ? window.location.origin || null
      : null;
  } catch (_error) {
    return null;
  }
})();
```

### 2. Enhanced Origin Validation
**Before:**
```javascript
messageHandler = (event) => {
  if (!frame || event.source !== frame.contentWindow) return;
  // Accept messages from player origin or if playerOrigin not set yet
  if (event.origin && playerOrigin && event.origin !== playerOrigin) return;
  const { data } = event;
```

**After:**
```javascript
messageHandler = (event) => {
  if (!frame || event.source !== frame.contentWindow) return;
  // Security: Validate origin - reject messages if origin doesn't match expected playerOrigin
  // Never accept messages when playerOrigin is null or '*' - these are insecure fallbacks
  if (!playerOrigin || playerOrigin === '*') {
    // Reject messages until we can determine the actual origin from iframe src
    return;
  }
  // Strict origin check: must match exactly
  if (!event.origin || event.origin !== playerOrigin) {
    return;
  }
  const { data } = event;
```

### 3. Fixed Iframe Origin Fallback
**Before:**
```javascript
try {
  playerOrigin = window.location.origin;
} catch (__error) {
  playerOrigin = '*';
}
```

**After:**
```javascript
try {
  playerOrigin = window.location.origin;
} catch (__error) {
  // Security: Never use '*' as fallback - reject messages until we can determine origin
  // This prevents accepting messages from any origin
  playerOrigin = null;
}
```

## Security Impact

### Before Fix
- Messages could be accepted from any origin when `playerOrigin` was `'*'`
- This created a security vulnerability where malicious sites could send messages to the bridge
- The validation check was incomplete and could be bypassed

### After Fix
- Messages are only accepted when `playerOrigin` is a valid origin string
- Messages are rejected when `playerOrigin` is `null` or `'*'`
- Strict origin matching prevents any bypass attempts
- No messages are accepted until the actual origin is determined from the iframe src

## Testing Recommendations

1. **Test with valid origin:**
   - Verify messages are accepted when origin matches
   - Verify messages are rejected when origin doesn't match

2. **Test with null origin:**
   - Verify messages are rejected when `playerOrigin` is `null`
   - Verify origin is set correctly from iframe src

3. **Test with '*' fallback (shouldn't happen anymore):**
   - Verify messages are rejected if `playerOrigin` is `'*'` (defense in depth)

4. **Test cross-origin scenarios:**
   - Verify messages from different origins are rejected
   - Verify messages from same origin are accepted

## Files Changed

- `preview/app/survey/bridge.js`
  - Line 221-231: Changed fallback from `'*'` to `null`
  - Line 327-338: Enhanced origin validation in Legacy Bridge
  - Line 404-411: Changed iframe origin fallback from `'*'` to `null`
  - Line 636-647: Enhanced origin validation in Protocol Bridge

## Related Security Considerations

- The `event.source !== frame.contentWindow` check provides additional security
- URL scheme validation in `handleLinkClick` and `handleRedirect` prevents XSS attacks
- These fixes complement existing security measures

## Commit Message Suggestion

```
security: fix origin validation bypass in bridge message handlers

- Replace insecure '*' fallback with null
- Add explicit validation to reject messages when origin is null or '*'
- Require strict origin matching for all postMessage handlers
- Prevents accepting messages from any origin when origin can't be determined

Fixes security vulnerabilities where messages could be accepted from
untrusted origins when playerOrigin fallback was used.
```

