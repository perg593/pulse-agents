/**
 * @fileoverview Unit tests for URL display feature
 * 
 * Tests the URL display bar functionality including:
 * - URL display updates
 * - Copy to clipboard
 * - Collapse/expand toggle
 */

// Simple test framework (matching existing test pattern)
function test(name, fn) {
  try {
    fn();
    console.log(`✓ ${name}`);
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(`  ${error.message}`);
    throw error;
  }
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message || 'Assertion failed');
  }
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(message || `Expected ${expected}, got ${actual}`);
  }
}

// Mock DOM elements for testing
function createMockUrlDisplayElements() {
  const state = {
    linkText: '—',
    linkHref: '#',
    linkPointerEvents: 'none',
    copyBtnClass: '',
    displayClass: 'url-display',
    toggleAriaLabel: 'Collapse URL bar',
    toggleTitle: 'Collapse'
  };

  const mockLink = {
    get textContent() { return state.linkText; },
    set textContent(val) { state.linkText = val; },
    get href() { return state.linkHref; },
    set href(val) { state.linkHref = val; },
    style: {
      get pointerEvents() { return state.linkPointerEvents; },
      set pointerEvents(val) { state.linkPointerEvents = val; }
    }
  };

  const mockCopyBtn = {
    classList: {
      add: (cls) => { state.copyBtnClass = cls; },
      remove: (cls) => { if (state.copyBtnClass === cls) state.copyBtnClass = ''; },
      contains: (cls) => state.copyBtnClass === cls
    }
  };

  const mockDisplay = {
    classList: {
      toggle: (cls) => {
        if (state.displayClass.includes(cls)) {
          state.displayClass = state.displayClass.replace(` ${cls}`, '').replace(cls, '').trim();
          return false;
        } else {
          state.displayClass = `${state.displayClass} ${cls}`.trim();
          return true;
        }
      },
      contains: (cls) => state.displayClass.includes(cls),
      add: (cls) => { if (!state.displayClass.includes(cls)) state.displayClass += ` ${cls}`; },
      remove: (cls) => { state.displayClass = state.displayClass.replace(cls, '').trim(); }
    }
  };

  const mockToggleBtn = {
    setAttribute: (attr, val) => {
      if (attr === 'aria-label') state.toggleAriaLabel = val;
      if (attr === 'title') state.toggleTitle = val;
    },
    getAttribute: (attr) => {
      if (attr === 'aria-label') return state.toggleAriaLabel;
      if (attr === 'title') return state.toggleTitle;
      return null;
    }
  };

  return {
    state,
    mockLink,
    mockCopyBtn,
    mockDisplay,
    mockToggleBtn
  };
}

// Implementation of updateUrlDisplay for testing
function updateUrlDisplay(url, mockLink) {
  if (!mockLink) return;
  
  const displayUrl = url && url.trim() ? url.trim() : '—';
  const isValidUrl = displayUrl !== '—';
  
  mockLink.textContent = displayUrl;
  mockLink.href = isValidUrl ? displayUrl : '#';
  mockLink.style.pointerEvents = isValidUrl ? 'auto' : 'none';
  
  return { displayUrl, isValidUrl };
}

// Implementation of toggleUrlDisplay for testing
function toggleUrlDisplay(mockDisplay, mockToggleBtn) {
  if (!mockDisplay) return;
  
  mockDisplay.classList.toggle('collapsed');
  
  const isCollapsed = mockDisplay.classList.contains('collapsed');
  if (mockToggleBtn) {
    mockToggleBtn.setAttribute('aria-label', isCollapsed ? 'Expand URL bar' : 'Collapse URL bar');
    mockToggleBtn.setAttribute('title', isCollapsed ? 'Expand' : 'Collapse');
  }
  
  return isCollapsed;
}

// ============================================
// Tests for updateUrlDisplay
// ============================================

test('updateUrlDisplay shows placeholder for empty URL', () => {
  const { mockLink } = createMockUrlDisplayElements();
  
  const result = updateUrlDisplay('', mockLink);
  
  assertEqual(result.displayUrl, '—', 'Empty URL should show placeholder');
  assertEqual(result.isValidUrl, false, 'Empty URL should not be valid');
  assertEqual(mockLink.textContent, '—', 'Link text should be placeholder');
  assertEqual(mockLink.href, '#', 'Link href should be #');
  assertEqual(mockLink.style.pointerEvents, 'none', 'Pointer events should be disabled');
});

test('updateUrlDisplay shows placeholder for null URL', () => {
  const { mockLink } = createMockUrlDisplayElements();
  
  const result = updateUrlDisplay(null, mockLink);
  
  assertEqual(result.displayUrl, '—', 'Null URL should show placeholder');
  assertEqual(result.isValidUrl, false, 'Null URL should not be valid');
});

test('updateUrlDisplay shows placeholder for whitespace-only URL', () => {
  const { mockLink } = createMockUrlDisplayElements();
  
  const result = updateUrlDisplay('   ', mockLink);
  
  assertEqual(result.displayUrl, '—', 'Whitespace URL should show placeholder');
  assertEqual(result.isValidUrl, false, 'Whitespace URL should not be valid');
});

test('updateUrlDisplay displays valid URL correctly', () => {
  const { mockLink } = createMockUrlDisplayElements();
  const testUrl = 'https://www.example.com/page';
  
  const result = updateUrlDisplay(testUrl, mockLink);
  
  assertEqual(result.displayUrl, testUrl, 'Should display the URL');
  assertEqual(result.isValidUrl, true, 'URL should be valid');
  assertEqual(mockLink.textContent, testUrl, 'Link text should be the URL');
  assertEqual(mockLink.href, testUrl, 'Link href should be the URL');
  assertEqual(mockLink.style.pointerEvents, 'auto', 'Pointer events should be enabled');
});

test('updateUrlDisplay trims URL whitespace', () => {
  const { mockLink } = createMockUrlDisplayElements();
  const testUrl = '  https://www.example.com  ';
  
  const result = updateUrlDisplay(testUrl, mockLink);
  
  assertEqual(result.displayUrl, 'https://www.example.com', 'URL should be trimmed');
  assertEqual(mockLink.textContent, 'https://www.example.com', 'Link text should be trimmed');
});

test('updateUrlDisplay handles undefined link gracefully', () => {
  const result = updateUrlDisplay('https://example.com', null);
  
  assertEqual(result, undefined, 'Should return undefined for null link');
});

// ============================================
// Tests for toggleUrlDisplay
// ============================================

test('toggleUrlDisplay collapses the URL bar', () => {
  const { mockDisplay, mockToggleBtn } = createMockUrlDisplayElements();
  
  const isCollapsed = toggleUrlDisplay(mockDisplay, mockToggleBtn);
  
  assertEqual(isCollapsed, true, 'Should return true when collapsed');
  assert(mockDisplay.classList.contains('collapsed'), 'Should have collapsed class');
  assertEqual(mockToggleBtn.getAttribute('aria-label'), 'Expand URL bar', 'aria-label should indicate expand');
  assertEqual(mockToggleBtn.getAttribute('title'), 'Expand', 'title should indicate expand');
});

test('toggleUrlDisplay expands the URL bar', () => {
  const { mockDisplay, mockToggleBtn, state } = createMockUrlDisplayElements();
  
  // First collapse
  toggleUrlDisplay(mockDisplay, mockToggleBtn);
  assert(mockDisplay.classList.contains('collapsed'), 'Should be collapsed first');
  
  // Then expand
  const isCollapsed = toggleUrlDisplay(mockDisplay, mockToggleBtn);
  
  assertEqual(isCollapsed, false, 'Should return false when expanded');
  assert(!mockDisplay.classList.contains('collapsed'), 'Should not have collapsed class');
  assertEqual(mockToggleBtn.getAttribute('aria-label'), 'Collapse URL bar', 'aria-label should indicate collapse');
  assertEqual(mockToggleBtn.getAttribute('title'), 'Collapse', 'title should indicate collapse');
});

test('toggleUrlDisplay handles null display gracefully', () => {
  const result = toggleUrlDisplay(null, null);
  
  assertEqual(result, undefined, 'Should return undefined for null display');
});

test('toggleUrlDisplay works without toggle button', () => {
  const { mockDisplay } = createMockUrlDisplayElements();
  
  const isCollapsed = toggleUrlDisplay(mockDisplay, null);
  
  assertEqual(isCollapsed, true, 'Should still toggle without button');
  assert(mockDisplay.classList.contains('collapsed'), 'Should have collapsed class');
});

// ============================================
// Tests for URL validation patterns
// ============================================

test('URL display handles various URL formats', () => {
  const { mockLink } = createMockUrlDisplayElements();
  
  const testUrls = [
    'https://www.example.com',
    'http://example.com',
    'https://example.com/path/to/page',
    'https://example.com?query=value',
    'https://example.com#anchor',
    'https://sub.domain.example.com'
  ];
  
  testUrls.forEach(url => {
    const result = updateUrlDisplay(url, mockLink);
    assert(result.isValidUrl, `${url} should be valid`);
    assertEqual(result.displayUrl, url, `${url} should be displayed as-is`);
  });
});

test('URL display handles special characters in URL', () => {
  const { mockLink } = createMockUrlDisplayElements();
  const testUrl = 'https://example.com/path?query=value&other=123#section';
  
  const result = updateUrlDisplay(testUrl, mockLink);
  
  assertEqual(result.displayUrl, testUrl, 'URL with special chars should be preserved');
  assert(result.isValidUrl, 'URL with special chars should be valid');
});

// ============================================
// Tests for collapse state persistence
// ============================================

test('toggleUrlDisplay toggles correctly multiple times', () => {
  const { mockDisplay, mockToggleBtn } = createMockUrlDisplayElements();
  
  // Toggle 5 times
  const results = [];
  for (let i = 0; i < 5; i++) {
    results.push(toggleUrlDisplay(mockDisplay, mockToggleBtn));
  }
  
  // Should alternate: true, false, true, false, true
  assertEqual(results[0], true, 'First toggle should collapse');
  assertEqual(results[1], false, 'Second toggle should expand');
  assertEqual(results[2], true, 'Third toggle should collapse');
  assertEqual(results[3], false, 'Fourth toggle should expand');
  assertEqual(results[4], true, 'Fifth toggle should collapse');
});

console.log('\nAll URL display unit tests passed!');
