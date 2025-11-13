# PR Blocking Issue Summary

**Date**: 2025-01-27  
**Issue**: Build step fails in CI because `pi-master` directory is missing

## Problem

Your PRs are blocked because the CI build step (`npm run build:widgets`) fails with:

```
Error: ENOENT: no such file or directory, chdir '/Users/projas/pulse_widgets' -> '/Users/projas/pulse_widgets/pi-master'
```

## Root Cause

The `scripts/build/generate-widgets.js` script tries to change directory to `pi-master` without checking if it exists first. The `pi-master` directory is **optional** (as seen in `scripts/launch/services.sh` which checks for it), but the build script doesn't handle its absence.

## Solution

Two options:

### Option 1: Make Build Script Handle Missing Directory (Recommended)

Update `scripts/build/generate-widgets.js` to check if `pi-master` exists before using it, similar to how the launch script handles it.

### Option 2: Update CI to Skip Widget Build When Directory Missing

Update `.github/workflows/ci.yml` to conditionally run the widget build step only if `pi-master` exists.

## Immediate Action Items

1. **Fix the build script** to handle missing `pi-master` directory
2. **Test locally** to ensure the fix works
3. **Push the fix** to your PR branches
4. **Verify CI passes** after the fix

## Files That Need Changes

1. `scripts/build/generate-widgets.js` - Add directory existence check
2. (Optional) `.github/workflows/ci.yml` - Make widget build conditional

## Next Steps

See `docs/guides/pr-merge-troubleshooting.md` for complete troubleshooting guide.

