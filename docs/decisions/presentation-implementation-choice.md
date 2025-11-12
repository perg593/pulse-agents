# Decision: Presentation Implementation Consolidation

**Date**: 2025-02-15  
**Status**: Decided  
**Context**: Two presentation implementations exist - `PresentationController` (ES modules) and `PresentationService` (CommonJS)

## Problem

The codebase currently has two presentation implementations:

1. **PresentationController** (`preview/basic/lib/presentationController.js`)
   - ES module (export class)
   - Used in `preview/basic/preview.js`
   - Simpler implementation
   - Manual lock and auto cooldown logic

2. **PresentationService** (`preview/basic/services/presentationService.js`)
   - CommonJS module (require/module.exports)
   - More comprehensive implementation
   - Includes state machine, queue, deduplicator
   - Better architecture but not currently integrated

## Decision

**Keep PresentationController for now, document PresentationService as future enhancement**

### Rationale

1. **Current Usage**: `PresentationController` is actively used in `preview.js` and works correctly
2. **Integration Complexity**: Migrating to `PresentationService` would require significant refactoring of `preview.js`
3. **Risk vs Benefit**: The current implementation works well; migration risk outweighs immediate benefits
4. **Future Path**: `PresentationService` provides better architecture and can be integrated incrementally later

## Implementation Strategy

### Current State
- `preview.js` uses `PresentationController` directly
- `PresentationController` handles manual lock and auto cooldown
- Works correctly with existing code

### Future Enhancement Path
1. Keep `PresentationService` as reference implementation
2. Gradually migrate functionality from `PresentationController` to `PresentationService`
3. Consider integration when doing major refactoring of `preview.js`

## Alternatives Considered

### Option 1: Migrate to PresentationService (Rejected)
- **Pros**: Better architecture, state machine, comprehensive features
- **Cons**: High risk, requires extensive refactoring, may break existing functionality
- **Decision**: Too risky for current state

### Option 2: Remove PresentationService (Rejected)
- **Pros**: Eliminates confusion
- **Cons**: Loses good architecture reference
- **Decision**: Keep as reference for future work

### Option 3: Keep Both (Chosen)
- **Pros**: Low risk, maintains current functionality, preserves future options
- **Cons**: Some code duplication
- **Decision**: Best balance of risk and future flexibility

## Notes

- `PresentationService` is well-designed and could be valuable in the future
- Current `PresentationController` implementation is sufficient for current needs
- Both implementations handle duplicate prevention, just at different levels
- No immediate need to consolidate - can be done incrementally

## Related

- Quality Evaluation: `docs/ask/2025-02-15_comprehensive-application-quality-evaluation.md`
- Presentation Scenarios: `docs/guides/preview/presentation-scenarios.md`
- Architecture Overview: `docs/architecture/preview-system-overview.md`

