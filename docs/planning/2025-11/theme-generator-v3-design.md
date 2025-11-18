# Theme Generator v3 - Design Document

**Date:** 2025-11-XX  
**Status:** Design Phase  
**Version:** 3.0

## Executive Summary

Theme Generator v3 is a complete redesign that incorporates learnings from v1 and v2 while addressing fragmentation, integration gaps, and technical debt. This document defines clear objectives, requirements, architecture, and implementation phases for building a unified, production-ready theme generation system.

---

## 1. Objectives & Success Criteria

### Primary Objectives

1. **Unified Implementation**: Single, cohesive theme generator that replaces v1 and v2
2. **Full Integration**: Seamlessly integrated with preview app and production workflows
3. **Production Quality**: Matches curated CSS output quality and completeness
4. **Maintainability**: Follows project conventions, comprehensive tests, clear documentation
5. **Extensibility**: Architecture supports future enhancements without breaking changes

### Success Criteria

- ✅ Generates CSS that matches curated theme quality (parity with `crocs_theme.css`)
- ✅ 100% integration with preview app (no separate servers or ports)
- ✅ Comprehensive test coverage (>80% unit, >60% integration)
- ✅ Follows all project conventions (errors, logging, validation, paths)
- ✅ Single output directory structure used by all consumers
- ✅ TypeScript for type safety, CommonJS for compatibility
- ✅ Clear API boundaries and documentation
- ✅ Performance: <30s for typical site analysis

---

## 2. Requirements

### 2.1 Functional Requirements

#### FR1: Website Analysis
- **FR1.1**: Extract brand colors (backgrounds, text, accents, borders)
- **FR1.2**: Extract font families, sizes, weights
- **FR1.3**: Extract CSS custom properties (`:root` variables)
- **FR1.4**: Extract logo colors from images and SVGs
- **FR1.5**: Support multi-page crawling (configurable depth)
- **FR1.6**: Handle slow-loading sites with timeouts and fallbacks
- **FR1.7**: Support both light and dark mode detection
- **FR1.8**: Provide confidence scores for extracted values

#### FR2: Theme Generation
- **FR2.1**: Generate 4 theme variations (Brand Faithful, Light, Dark, Minimalist)
- **FR2.2**: Generate CSS matching curated theme structure
- **FR2.3**: Support all widget types (topbar, bottombar, docked, inline, fullscreen)
- **FR2.4**: Support all question types (single choice, multiple choice, free text, slider, NPS, custom content)
- **FR2.5**: Support all answer layouts (fixed 1-14 per row, variable with all alignments)
- **FR2.6**: Generate mobile-responsive CSS
- **FR2.7**: Generate legacy browser compatibility CSS
- **FR2.8**: Validate WCAG contrast ratios
- **FR2.9**: Support JSON token input/output for manual editing

#### FR3: Integration
- **FR3.1**: CLI interface for server-side generation
- **FR3.2**: Browser API for client-side generation (via proxy)
- **FR3.3**: Unified output directory structure
- **FR3.4**: Preview app integration (no separate server)
- **FR3.5**: Manifest generation for preview app
- **FR3.6**: Theme history and management

#### FR4: Output Quality
- **FR4.1**: CSS structure matches curated themes exactly
- **FR4.2**: All selectors from curated CSS are generated
- **FR4.3**: Proper CSS variable scoping
- **FR4.4**: Vendor prefix support for legacy browsers
- **FR4.5**: Comment structure matches curated format

### 2.2 Non-Functional Requirements

#### NFR1: Code Quality
- **NFR1.1**: Follow all project conventions (`.cursorrules`)
- **NFR1.2**: Use centralized error handling (`lib/errors.js`)
- **NFR1.3**: Use centralized logging (`lib/logger.js`)
- **NFR1.4**: Use centralized validation (`lib/validators.js`)
- **NFR1.5**: Use centralized paths (`config/paths.js`, `lib/paths.js`)
- **NFR1.6**: TypeScript for type safety
- **NFR1.7**: CommonJS modules for Node.js compatibility
- **NFR1.8**: JSDoc comments for all exported functions

#### NFR2: Testing
- **NFR2.1**: >80% unit test coverage
- **NFR2.2**: >60% integration test coverage
- **NFR2.3**: Test all extraction methods
- **NFR2.4**: Test all theme generation paths
- **NFR2.5**: Test CSS output against curated examples
- **NFR2.6**: Visual regression tests for preview widgets

#### NFR3: Performance
- **NFR3.1**: Site analysis: <30s for typical site
- **NFR3.2**: Theme generation: <5s for 4 themes
- **NFR3.3**: CSS compilation: <1s per theme
- **NFR3.4**: Memory efficient (no memory leaks)
- **NFR3.5**: Browser reuse for multi-page crawling

#### NFR4: Documentation
- **NFR4.1**: API documentation for all public functions
- **NFR4.2**: Architecture decision records
- **NFR4.3**: Integration guides
- **NFR4.4**: Usage examples
- **NFR4.5**: Troubleshooting guides

#### NFR5: Maintainability
- **NFR5.1**: Clear module boundaries
- **NFR5.2**: Single responsibility principle
- **NFR5.3**: DRY (Don't Repeat Yourself)
- **NFR5.4**: Comprehensive error messages
- **NFR5.5**: Debug logging for troubleshooting

---

## 3. Architecture

### 3.1 High-Level Architecture

```markdown
┌─────────────────────────────────────────────────────────────┐
│                    Theme Generator v3                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │   Extraction     │         │   Generation    │         │
│  │   Layer          │────────▶│   Layer          │         │
│  │                  │         │                  │         │
│  │ • Site Analyzer  │         │ • Theme Builder │         │
│  │ • Color Extractor│         │ • CSS Compiler  │         │
│  │ • Font Extractor │         │ • Validator      │         │
│  │ • Logo Analyzer  │         │ • Formatter      │         │
│  └──────────────────┘         └──────────────────┘         │
│           │                            │                    │
│           │                            │                    │
│  ┌────────▼────────────────────────────▼────────┐          │
│  │         Integration Layer                    │          │
│  │  • CLI Interface                             │          │
│  │  • Browser API                               │          │
│  │  • Preview Integration                       │          │
│  └──────────────────────────────────────────────┘          │
│                                                             │
│  ┌──────────────────────────────────────────────┐          │
│  │         Shared Infrastructure                 │          │
│  │  • lib/errors.js                             │          │
│  │  • lib/logger.js                             │          │
│  │  • lib/validators.js                         │          │
│  │  • config/paths.js                           │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Module Structure

```
theme-generator/v3/
├── package.json
├── tsconfig.json
├── README.md
│
├── src/
│   ├── index.ts                    # Main entry point
│   │
│   ├── extraction/                 # Website analysis
│   │   ├── siteAnalyzer.ts         # Main analyzer orchestrator
│   │   ├── colorExtractor.ts       # Color extraction logic
│   │   ├── fontExtractor.ts        # Font extraction logic
│   │   ├── logoAnalyzer.ts         # Logo color extraction
│   │   ├── cssVarExtractor.ts      # CSS variable extraction
│   │   └── types.ts                # Extraction types
│   │
│   ├── generation/                 # Theme generation
│   │   ├── themeBuilder.ts         # Builds theme tokens
│   │   ├── cssCompiler.ts          # Compiles tokens to CSS
│   │   ├── cssFormatter.ts          # Formats CSS output
│   │   ├── validator.ts             # Validates themes/CSS
│   │   └── types.ts                 # Generation types
│   │
│   ├── integration/                # Integration interfaces
│   │   ├── cli.ts                  # CLI interface
│   │   ├── browser.ts              # Browser API
│   │   └── preview.ts              # Preview app integration
│   │
│   └── utils/                      # Shared utilities
│       ├── colorUtils.ts           # Color manipulation
│       ├── fontUtils.ts            # Font processing
│       └── pathUtils.ts            # Path utilities (uses lib/paths.js)
│
├── tests/
│   ├── unit/
│   │   ├── extraction/
│   │   ├── generation/
│   │   └── integration/
│   └── integration/
│       ├── end-to-end.test.ts
│       └── preview-integration.test.ts
│
└── dist/                           # Compiled JavaScript (CommonJS)
```

### 3.3 Key Design Decisions

#### DD1: TypeScript with CommonJS Output
- **Decision**: Use TypeScript for development, compile to CommonJS
- **Rationale**: Type safety during development, compatibility with existing codebase
- **Alternatives Considered**: Pure JavaScript (rejected - no type safety), ES modules (rejected - breaks compatibility)

#### DD2: Unified Extraction Engine
- **Decision**: Single extraction engine that combines best of v1 and v2 approaches
- **Rationale**: Playwright for accuracy, but with v1's simplicity and error handling
- **Alternatives Considered**: Keep v1 and v2 separate (rejected - fragmentation), Use only v1 (rejected - less accurate), Use only v2 (rejected - not integrated)

#### DD3: Single Output Directory
- **Decision**: Use `theme-generator/output/client-themes/` for all output
- **Rationale**: Consistency with preview app expectations, single source of truth
- **Alternatives Considered**: Separate directories (rejected - causes confusion)

#### DD4: Browser API via Proxy
- **Decision**: Browser-side generation calls server-side extraction via proxy
- **Rationale**: Maintains browser compatibility while leveraging server-side accuracy
- **Alternatives Considered**: Pure browser-side (rejected - less accurate), Pure server-side (rejected - breaks preview integration)

#### DD5: CSS Parity First
- **Decision**: Prioritize matching curated CSS structure over new features
- **Rationale**: Production quality requires matching existing curated themes
- **Alternatives Considered**: New features first (rejected - quality gap)

---

## 4. Learnings from Previous Versions

### 4.1 From v1 (JavaScript/Puppeteer)

**What Worked:**
- ✅ Integration with preview app
- ✅ Following project conventions
- ✅ Error handling and logging
- ✅ Unit tests
- ✅ Simple, maintainable code

**What Didn't Work:**
- ❌ Limited extraction accuracy
- ❌ No logo color extraction
- ❌ No confidence scoring
- ❌ Hardcoded logic (AirSupra palette)
- ❌ Browser-side analysis limitations

**Takeaways:**
- Keep integration patterns
- Keep convention compliance
- Keep error handling approach
- Improve extraction accuracy
- Add logo analysis

### 4.2 From v2 (TypeScript/Playwright)

**What Worked:**
- ✅ Sophisticated extraction (Playwright, logo analysis)
- ✅ Dynamic schema parsing
- ✅ Confidence scoring
- ✅ Evidence tracking
- ✅ TypeScript type safety

**What Didn't Work:**
- ❌ Not integrated with preview app
- ❌ Separate output directory
- ❌ No unit tests
- ❌ Hardcoded paths
- ❌ Not following project conventions
- ❌ Separate web UI server

**Takeaways:**
- Use Playwright for accuracy
- Use TypeScript for type safety
- Use dynamic schema parsing
- Add confidence scoring
- Integrate with preview app
- Follow project conventions

---

## 5. Implementation Phases

### Phase 1: Foundation (Week 1-2)
**Goal**: Set up project structure and core infrastructure

**Tasks:**
1. Create `theme-generator/v3/` directory structure
2. Set up TypeScript configuration (compile to CommonJS)
3. Set up package.json with dependencies
4. Create base types and interfaces
5. Set up test infrastructure
6. Integrate with shared infrastructure (`lib/`, `config/`)

**Deliverables:**
- Project structure
- TypeScript configuration
- Base types
- Test infrastructure
- Integration with shared libs

### Phase 2: Extraction Engine (Week 3-4)
**Goal**: Build unified extraction engine

**Tasks:**
1. Implement `siteAnalyzer.ts` (orchestrator)
2. Implement `colorExtractor.ts` (combine v1 + v2 approaches)
3. Implement `fontExtractor.ts`
4. Implement `logoAnalyzer.ts` (from v2)
5. Implement `cssVarExtractor.ts` (from v2)
6. Add confidence scoring
7. Write unit tests for all extractors

**Deliverables:**
- Complete extraction engine
- Unit tests (>80% coverage)
- Documentation

### Phase 3: Generation Engine (Week 5-7)
**Goal**: Build theme generation and CSS compilation

**Tasks:**
1. Implement `themeBuilder.ts` (builds 4 theme variations)
2. Implement `cssCompiler.ts` (matches curated CSS structure)
3. Implement CSS sections:
   - Base scaffold
   - Answer layouts (legacy + modern)
   - Question types (all 6 types)
   - Widget types (all 5 types)
   - UI elements (invitation, thank you, CTA)
   - Mobile responsive
   - Legacy browser support
4. Implement `cssFormatter.ts` (matches curated format)
5. Implement `validator.ts` (WCAG contrast, required fields)
6. Write unit tests
7. Compare output with curated themes

**Deliverables:**
- Complete generation engine
- CSS output matching curated themes
- Unit tests (>80% coverage)
- Parity validation

### Phase 4: Integration (Week 8-9)
**Goal**: Integrate with preview app and CLI

**Tasks:**
1. Implement `cli.ts` (replaces v1 `main.js`)
2. Implement `browser.ts` (API for preview app)
3. Implement `preview.ts` (preview app integration)
4. Update preview app to use v3 API
5. Update manifest generation
6. Write integration tests
7. Test end-to-end workflows

**Deliverables:**
- CLI interface
- Browser API
- Preview app integration
- Integration tests
- End-to-end validation

### Phase 5: Quality & Documentation (Week 10)
**Goal**: Polish, test, and document

**Tasks:**
1. Visual regression testing
2. Performance optimization
3. Error message improvements
4. API documentation
5. Architecture documentation
6. Usage guides
7. Migration guide from v1/v2

**Deliverables:**
- Complete documentation
- Performance benchmarks
- Migration guide
- Production-ready code

---

## 6. Testing Strategy

### 6.1 Unit Tests

**Coverage Targets:**
- Extraction: >85%
- Generation: >85%
- Utilities: >90%
- Overall: >80%

**Test Categories:**
- Color extraction (various formats, edge cases)
- Font extraction (fallbacks, parsing)
- Logo analysis (images, SVGs, CORS)
- Theme building (all 4 variations)
- CSS compilation (all sections)
- Validation (contrast, required fields)

### 6.2 Integration Tests

**Test Scenarios:**
- End-to-end: URL → Analysis → Generation → CSS
- CLI: Full command-line workflow
- Browser API: Preview app integration
- Multi-page crawling
- Error handling and recovery
- Performance benchmarks

### 6.3 Visual Regression Tests

**Test Cases:**
- Compare generated CSS with curated themes
- Test all widget types
- Test all question types
- Test all answer layouts
- Test mobile responsive
- Test legacy browser compatibility

### 6.4 Test Data

**Test Sites:**
- Simple sites (minimal CSS)
- Complex sites (many colors/fonts)
- Dark mode sites
- Sites with logos
- Sites with CSS variables
- Slow-loading sites
- Sites with errors

---

## 7. Migration Strategy

### 7.1 From v1

**Steps:**
1. v3 CLI maintains same interface: `node v3/cli.js <url> <client-name>`
2. Output format compatible (same directory structure)
3. Preview app can use v3 API transparently
4. Gradual migration: v1 and v3 can coexist

**Breaking Changes:**
- None (maintains compatibility)

### 7.2 From v2

**Steps:**
1. v3 provides equivalent functionality
2. Output format compatible (same directory structure)
3. Migration script to convert v2 outputs if needed
4. Documentation for v2 users

**Breaking Changes:**
- Separate web UI server no longer needed (integrated into preview app)

---

## 8. Risk Mitigation

### Risk 1: CSS Parity Not Achieved
- **Mitigation**: Continuous comparison with curated themes during development
- **Contingency**: Manual adjustments to CSS compiler

### Risk 2: Performance Issues
- **Mitigation**: Performance benchmarks in Phase 5
- **Contingency**: Optimization passes, caching

### Risk 3: Integration Complexity
- **Mitigation**: Incremental integration, comprehensive tests
- **Contingency**: Fallback to v1 if needed

### Risk 4: TypeScript Compilation Issues
- **Mitigation**: Early TypeScript setup, continuous compilation checks
- **Contingency**: JavaScript fallback for problematic modules

---

## 9. Success Metrics

### Code Quality
- ✅ >80% unit test coverage
- ✅ >60% integration test coverage
- ✅ Zero linting errors
- ✅ All project conventions followed

### Output Quality
- ✅ CSS structure matches curated themes (>95% similarity)
- ✅ All selectors from curated CSS present
- ✅ WCAG contrast validation passes
- ✅ Visual regression tests pass

### Integration
- ✅ Preview app uses v3 seamlessly
- ✅ CLI works identically to v1
- ✅ No separate servers needed
- ✅ Single output directory

### Performance
- ✅ Site analysis: <30s (typical site)
- ✅ Theme generation: <5s (4 themes)
- ✅ CSS compilation: <1s (per theme)

---

## 10. Open Questions

1. **Browser Automation**: Should we use Playwright or Puppeteer?
   - **Recommendation**: Playwright (more accurate, better API)
   - **Decision Needed**: Confirm Playwright is acceptable dependency

2. **CSS Compiler**: Should we use a CSS parser library or string building?
   - **Recommendation**: String building (matches curated format exactly)
   - **Decision Needed**: Confirm approach

3. **Preview Integration**: Should v3 replace v1 immediately or coexist?
   - **Recommendation**: Coexist initially, then deprecate v1
   - **Decision Needed**: Migration timeline

4. **Output Format**: Should we maintain JSON token format?
   - **Recommendation**: Yes (for manual editing and future features)
   - **Decision Needed**: Confirm requirement

---

## 11. Next Steps

1. **Review this design document** with stakeholders
2. **Answer open questions** and make decisions
3. **Create detailed task breakdown** for Phase 1
4. **Set up project structure** and infrastructure
5. **Begin Phase 1 implementation**

---

## Appendix A: Comparison Matrix

| Feature | v1 | v2 | v3 (Target) |
|--------|----|----|-------------|
| **Language** | JavaScript | TypeScript | TypeScript |
| **Browser Automation** | Puppeteer | Playwright | Playwright |
| **Extraction Accuracy** | Good | Better | Best (combined) |
| **Logo Analysis** | ❌ | ✅ | ✅ |
| **Confidence Scoring** | ❌ | ✅ | ✅ |
| **Preview Integration** | ✅ | ❌ | ✅ |
| **Project Conventions** | ✅ | ❌ | ✅ |
| **Test Coverage** | ✅ | ❌ | ✅ |
| **Output Quality** | Good | Good | Excellent (parity) |
| **Documentation** | Good | Fair | Excellent |

---

## Appendix B: References

- [Theme Generator Assessment](./theme-generator-assessment.md) - Current state analysis
- [Theme Generator Parity Plan](../2025-10/theme-generator-parity.md) - CSS parity requirements
- [Theme Generator Upgrades](../2025-10/theme-generator-upgrades.md) - CSS enhancement plan
- [Architecture Overview](../../architecture/overview.md) - System architecture
- [Project Conventions](../../../.cursorrules) - Code style and conventions

---

**Document Status**: Draft  
**Last Updated**: 2025-11-XX  
**Next Review**: After stakeholder feedback
```

This design document provides:

1. Clear objectives and success criteria
2. Functional and non-functional requirements
3. Architecture with design decisions
4. Learnings from v1 and v2
5. Phased implementation plan
6. Testing strategy
7. Migration approach
8. Risk mitigation
9. Success metrics

It serves as the foundation for building v3. Should I:
1. Expand any section?
2. Add more technical details?
3. Create implementation task breakdowns?
4. Start Phase 1 implementation?
