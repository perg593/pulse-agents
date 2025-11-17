# Next Steps

## Current Status
- ✅ Security fixes implemented and tested
- ✅ Console errors analyzed (all external, not our code)
- ✅ On branch: `feature/custom-content-link-handling`
- ✅ PR #4 exists and is open

## Files to Commit (Custom Content Feature)

### 1. Security Fixes
- `preview/app/survey/bridge.js` - Origin validation security fixes

### 2. Documentation
- `SECURITY_FIXES.md` - Documentation of security fixes
- `CONSOLE_ERRORS_ANALYSIS.md` - Analysis of console errors
- `PR_DESCRIPTION_UPDATED.md` - Updated PR description
- `PR_REVIEW_SUMMARY.md` - PR review summary

## Files to Stash (Theme Generator - Not Ready)

- `preview/styles/examples/generated/themes.json` - Generated file
- `docs/planning/2025-11/theme-generator-v3-design*.md` - Theme generator docs
- `theme-generator/v3/` - Theme generator v3 code
- Various `package-lock.json` files in theme-generator directories
- Other theme generator related docs

## Recommended Next Steps

### Step 1: Stash Theme Generator Files
```bash
git stash push -m "theme-generator: additional files" \
  preview/styles/examples/generated/themes.json \
  docs/planning/2025-11/theme-generator-v3-design*.md \
  theme-generator/
```

### Step 2: Commit Security Fixes
```bash
git add preview/app/survey/bridge.js SECURITY_FIXES.md CONSOLE_ERRORS_ANALYSIS.md
git commit -m "security: fix origin validation in bridge message handlers

- Remove insecure '*' fallback - use null instead
- Add strict origin validation before accepting messages
- Add debug logging for origin validation failures
- Set playerOrigin before attaching listeners to prevent race conditions
- Handle both Legacy Bridge and Protocol Bridge message handlers

Fixes security issues flagged by Cursor bot:
- Security Bypass: Origin Validation Incomplete
- Security Flaw: Origin Validation Bypass"
```

### Step 3: Commit PR Documentation
```bash
git add PR_DESCRIPTION_UPDATED.md PR_REVIEW_SUMMARY.md CONSOLE_ERRORS_ANALYSIS.md
git commit -m "docs: add PR documentation and error analysis

- Add comprehensive PR description covering all features
- Add PR review summary with commit breakdown
- Add console errors analysis (all external, not our code)
- Document security fixes and validation"
```

### Step 4: Push to Remote
```bash
git push origin feature/custom-content-link-handling
```

### Step 5: Update PR #4
- Update PR description with `PR_DESCRIPTION_UPDATED.md` content
- Add comments about security fixes
- Mark as ready for review

## Alternative: Single Commit
If you prefer to commit everything together:

```bash
# Stash theme generator files first
git stash push -m "theme-generator: additional files" \
  preview/styles/examples/generated/themes.json \
  docs/planning/2025-11/theme-generator-v3-design*.md \
  theme-generator/

# Commit security fixes and docs together
git add preview/app/survey/bridge.js SECURITY_FIXES.md CONSOLE_ERRORS_ANALYSIS.md PR_DESCRIPTION_UPDATED.md PR_REVIEW_SUMMARY.md
git commit -m "security: fix origin validation + add PR documentation

Security Fixes:
- Remove insecure '*' fallback - use null instead
- Add strict origin validation before accepting messages
- Add debug logging for origin validation failures
- Set playerOrigin before attaching listeners to prevent race conditions
- Handle both Legacy Bridge and Protocol Bridge message handlers

Documentation:
- Add comprehensive PR description covering all features
- Add PR review summary with commit breakdown
- Add console errors analysis (all external, not our code)
- Document security fixes and validation

Fixes security issues flagged by Cursor bot."

# Push
git push origin feature/custom-content-link-handling
```

## After Committing

1. **Update PR #4** on GitHub:
   - Copy content from `PR_DESCRIPTION_UPDATED.md` to PR description
   - Add note about security fixes
   - Request review

2. **Test Checklist** (if not already done):
   - ✅ Custom content link clicks navigate main window
   - ✅ Custom content auto-redirect works
   - ✅ Control rail hides with `?present=XXXX`
   - ✅ No control rail flash
   - ✅ Origin validation working (no rejected messages)
   - ✅ Security fixes tested

3. **Ready for Review** when:
   - All commits pushed
   - PR description updated
   - Tests passing
   - Security fixes verified

