/**
 * @fileoverview Unit tests for StateMachine
 */

const { StateMachine } = require('../../../preview/basic/lib/stateMachine');

// Simple test framework
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

// Mock logger
jest.mock('../../../lib/logger', () => ({
  log: {
    debug: () => {},
    info: () => {},
    warn: () => {},
    error: () => {}
  }
}));

// Tests
test('StateMachine creates instance', () => {
  const sm = new StateMachine({
    initialState: 'idle',
    states: [{ name: 'idle' }],
    transitions: []
  });
  
  assert(sm instanceof StateMachine);
  assertEqual(sm.getState(), 'idle');
});

test('StateMachine transitions between states', () => {
  const sm = new StateMachine({
    initialState: 'idle',
    states: [
      { name: 'idle' },
      { name: 'active' }
    ],
    transitions: [
      { from: 'idle', to: 'active' }
    ]
  });
  
  assertEqual(sm.getState(), 'idle');
  assert(sm.transition('active'));
  assertEqual(sm.getState(), 'active');
});

test('StateMachine enforces valid transitions', () => {
  const sm = new StateMachine({
    initialState: 'idle',
    states: [
      { name: 'idle' },
      { name: 'active' },
      { name: 'done' }
    ],
    transitions: [
      { from: 'idle', to: 'active' },
      { from: 'active', to: 'done' }
    ]
  });
  
  // Valid transition
  assert(sm.transition('active'));
  
  // Invalid transition (idle -> done not defined)
  sm.reset();
  assert(!sm.canTransition('done'));
});

test('StateMachine respects guard conditions', () => {
  const sm = new StateMachine({
    initialState: 'idle',
    states: [
      { name: 'idle' },
      { name: 'active' }
    ],
    transitions: [
      {
        from: 'idle',
        to: 'active',
        guard: (context) => context.allowed === true
      }
    ]
  });
  
  // Guard blocks transition
  assert(!sm.canTransition('active', { allowed: false }));
  
  // Guard allows transition
  assert(sm.canTransition('active', { allowed: true }));
});

test('StateMachine calls onEnter and onExit callbacks', () => {
  let entered = false;
  let exited = false;
  
  const sm = new StateMachine({
    initialState: 'idle',
    states: [
      {
        name: 'idle',
        onExit: () => { exited = true; }
      },
      {
        name: 'active',
        onEnter: () => { entered = true; }
      }
    ],
    transitions: [
      { from: 'idle', to: 'active' }
    ]
  });
  
  sm.transition('active');
  
  assert(exited);
  assert(entered);
});

test('StateMachine resets to initial state', () => {
  const sm = new StateMachine({
    initialState: 'idle',
    states: [
      { name: 'idle' },
      { name: 'active' }
    ],
    transitions: [
      { from: 'idle', to: 'active' }
    ]
  });
  
  sm.transition('active');
  assertEqual(sm.getState(), 'active');
  
  sm.reset();
  assertEqual(sm.getState(), 'idle');
});

test('StateMachine maintains history', () => {
  const sm = new StateMachine({
    initialState: 'idle',
    states: [
      { name: 'idle' },
      { name: 'active' }
    ],
    transitions: [
      { from: 'idle', to: 'active' }
    ]
  });
  
  sm.transition('active');
  
  const history = sm.getHistory();
  assert(history.length >= 2); // Initial + transition
  assertEqual(history[history.length - 1].state, 'active');
});

console.log('\nAll StateMachine tests passed!');

