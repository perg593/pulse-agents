# Test Directory Consolidation Plan

## Current State Analysis

### Active Test Directories (Tracked)

1. **`tests/`** - Main centralized test suite ✅
   - **Location:** Root level
   - **Status:** Active, well-organized
   - **Contents:**
     - `unit/` - Unit tests (config, lib, generators)
     - `integration/` - Integration tests (preview, generators)
     - `fixtures/` - Shared test fixtures
     - `support/` - Test utilities
     - `run-all.sh` - Unified test runner
   - **References:** Used in package.json, tests/README.md

2. **`theme-generator/v2/tests/`** - Theme generator v2 tests ✅
   - **Location:** `theme-generator/v2/tests/`
   - **Status:** Active, uses Vitest
   - **Contents:**
     - `mapper.test.ts` - Mapper tests
     - `parser.test.ts` - Parser tests
   - **References:** Used in theme-generator/v2/package.json

3. **`pi-master/test/`** - Rails test directory ✅
   - **Location:** `pi-master/test/`
   - **Status:** Part of Rails app, should stay separate
   - **Contents:** Rails mailer previews

4. **`pi-master/spec/`** - Rails RSpec directory ✅
   - **Location:** `pi-master/spec/`
   - **Status:** Part of Rails app, should stay separate
   - **Contents:** Rails RSpec tests (controllers, models, etc.)

### Empty/Unused Directories (Untracked or Empty)

5. **`theme-generator/test/`** - Empty directory ❌
   - **Location:** `theme-generator/test/`
   - **Status:** Empty, untracked
   - **Action:** Remove

6. **`preview/tests/`** - Empty directory structure ❌
   - **Location:** `preview/tests/`
   - **Status:** Empty subdirectories (`services/`, `support/`)
   - **Note:** Test files have already moved to `tests/integration/preview/`
   - **Action:** Remove empty directory structure

### Legacy/Manual Testing Directories

7. **`legacy/testing/`** - Legacy testing assets ✅
   - **Location:** `legacy/testing/`
   - **Status:** Contains testing assets (lipsum)
   - **Contents:** Lipsum testing website files
   - **Action:** Keep as-is (documented legacy)

8. **`legacy/_manual-testing/`** - Manual testing screenshots ⚠️
   - **Location:** `legacy/_manual-testing/`
   - **Status:** Contains untracked screenshot images (27 files, ~79MB)
   - **Contents:** Versioned screenshot folders (v00-v06) with PNG images
   - **Action:** Move to `legacy/testing/manual/` for better organization

## Issues Identified

### 1. Inconsistent Naming
- Some use `tests/` (plural)
- Some use `test/` (singular)
- Some use `testing/` (gerund)

### 2. Empty Directories
- `theme-generator/test/` - Completely empty
- `preview/tests/` - Empty subdirectories only

### 3. Legacy Test References
- Documentation references `preview/tests/` but files may have moved
- Need to verify if files exist or are outdated references

### 4. Scattered Test Files
- Generator tests split between `tests/unit/generators/` and `theme-generator/v2/tests/`
- This is actually fine (version-specific tests stay with their version)

## Proposed Structure

```
tests/                                    # Main centralized test suite
├── unit/                                # Unit tests
│   ├── config/
│   ├── lib/
│   └── generators/                      # Shared generator tests
├── integration/                         # Integration tests
│   ├── preview/                         # Preview system tests
│   └── generators/                      # Generator integration tests
├── fixtures/                            # Shared test fixtures
├── support/                             # Test utilities
└── run-all.sh                          # Unified test runner

theme-generator/
├── v1/                                  # No tests here (use main tests/)
├── v2/
│   └── tests/                           # Version-specific tests (Vitest)
│       ├── mapper.test.ts
│       └── parser.test.ts

legacy/
└── testing/                            # Legacy testing assets
    ├── lipsum/                          # Lipsum testing files
    └── manual/                          # Manual testing screenshots (optional)

pi-master/                               # Rails app - keep separate
├── test/                                # Rails tests
└── spec/                                # Rails RSpec tests
```

## Consolidation Steps

### Step 1: Remove Empty Directories
- Remove `theme-generator/test/` (empty)
- Remove `preview/tests/` and its empty subdirectories (test files already moved to `tests/integration/preview/`)

### Step 2: Consolidate Manual Testing
- Move `legacy/_manual-testing/` → `legacy/testing/manual/` (27 screenshot files, ~79MB)
- This organizes all legacy testing assets under `legacy/testing/`

### Step 3: Verify Test References
- ✅ Test files already moved from `preview/tests/` to `tests/integration/preview/`
- Update documentation references to old `preview/tests/` paths

### Step 4: Update Documentation
- Update any references to old test paths
- Ensure all test locations are documented

## Files That Need Reference Updates (if any)

1. **Documentation:**
   - `docs/review/preview-implementation-review.md` - References `preview/tests/`
   - `docs/legacy/development-notes/` - May reference old test paths

2. **Package.json Scripts:**
   - Current scripts point to `tests/` - should be fine

3. **Test Runners:**
   - `tests/run-all.sh` - Already uses correct paths

## Benefits

1. **Clearer Structure:** All tests under `tests/` except version-specific ones
2. **Reduced Confusion:** No empty directories
3. **Better Organization:** Legacy tests clearly marked
4. **Consistent Naming:** Use `tests/` (plural) for main directory

## Notes

- **pi-master tests:** Keep separate (Rails app has its own test structure)
- **theme-generator/v2/tests:** Keep separate (version-specific, uses Vitest)
- **Main tests/:** This is the primary test suite for the toolkit

## Implementation Priority

1. **High Priority:** Remove empty directories
2. **Medium Priority:** Consolidate manual testing (if needed)
3. **Low Priority:** Update documentation references

