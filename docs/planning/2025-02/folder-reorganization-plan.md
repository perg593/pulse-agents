# Folder Reorganization Plan

## Current Issues

### 1. Awkward Folder Names

- **`Old-Pulse-Themes-Framework-2025/`** - Clumsy name with mixed hyphens and year suffix
  - Should be: `sass-framework/` or `legacy/sass-framework/` (since it's actively used, better at root)
  - Contains: SASS source files for theme generation
  - Status: **Actively used** by `pulse-theme-generator-v2`

- **`docs/theme_generator/` vs `docs/theme-generator/`** - Inconsistent naming
  - Should consolidate to: `docs/theme-generator/` (use hyphen consistently)

- **`lipsum_local/`** - Awkward underscore/hyphen mix
  - Should be: `lipsum-local/` or move to `legacy/testing/lipsum/`

### 2. Inconsistent Naming Patterns

- Some folders use hyphens (`theme-generator/`)
- Some use underscores (`theme_generator/`)
- Some use mixed (`lipsum_local/`)

## Proposed Changes

### High Priority

1. **Rename `Old-Pulse-Themes-Framework-2025/` → `sass-framework/`**
   - Cleaner, more descriptive
   - Follows hyphenated naming convention
   - Removes awkward year suffix
   - **Reasoning**: This is actively used SASS source code, not legacy

2. **Rename `docs/theme_generator/` → `docs/theme-generator/`**
   - Consolidate with existing `docs/theme-generator/`
   - Check if consolidation needed or if one should be removed

3. **Rename `lipsum_local/` → `legacy/testing/lipsum/`**
   - Consistent naming (hyphens)
   - Better organization (testing tools belong in legacy/testing)

### Medium Priority

4. **Review `pi-master/` placement**
   - If actively used: Keep as is
   - If legacy: Move to `legacy/pi-master/`

## Files That Need Reference Updates

### For `Old-Pulse-Themes-Framework-2025` → `sass-framework`

1. **Code Files:**
   - `pulse-theme-generator-v2/src/utils/config.ts` (line 21)
   - `pulse-theme-generator-v2/scripts/extract-theme.ts` (line 23)
   - `pulse-theme-generator-v2/scripts/map-to-pulse.ts` (line 19)
   - `tests/integration/generators/extraction.test.ts` (line 15)

2. **Documentation:**
   - `docs/theme-generator/testing.md` (line 178)
   - `docs/theme-generator/improvements.md` (line 171)
   - `docs/theme-generator/api-reference.md` (line 7)
   - `docs/theme-generator/evaluation.md` (line 62)
   - `docs/planning/2025-10/theme-framework-token-reference.md` (multiple references)

3. **Environment Variables:**
   - Default `PULSE_SASS_ROOT` path references

## Implementation Steps

1. ✅ Analyze current structure
2. ⏳ Create reorganization plan
3. ⏳ Move/rename folders using `git mv`
4. ⏳ Update all code references
5. ⏳ Update all documentation references
6. ⏳ Run tests to verify
7. ⏳ Commit changes

## Verification Checklist

- [ ] All code references updated
- [ ] All documentation references updated
- [ ] Tests pass
- [ ] No broken imports/paths
- [ ] Git history preserved (using `git mv`)

