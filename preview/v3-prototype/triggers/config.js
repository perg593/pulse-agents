export const TRIGGER_GROUPS = {
  behavioral: {
    label: 'Signal boosts',
    description: 'Quick, single-signal heuristics you can fire instantly.'
  },
  journeys: {
    label: 'Multi-step journeys',
    description: 'Composite behaviours that unfold over the session.'
  },
  lifecycle: {
    label: 'Lifecycle & loyalty',
    description: 'Account or identity cues that unlock targeted surveys.'
  },
  support: {
    label: 'Support & friction',
    description: 'Moments that suggest the user needs an assist.'
  }
};

export const TRIGGER_CONFIG = [
  {
    id: 'present_now',
    label: 'Present now',
    type: 'present',
    dom: 'present'
  },
  {
    id: 'exit_intent',
    label: 'Exit intent',
    description: 'Cursor accelerates toward browser chrome — catch them before they bounce.',
    dom: 'exit-intent',
    command: ['simulateExitIntent'],
    group: 'behavioral'
  },
  {
    id: 'scroll_60',
    label: 'Scroll depth 60%',
    description: 'Reaches deep content. Useful for post-content polls or NPS engagements.',
    dom: 'scroll-depth',
    command: ['simulateScrollDepth', { percent: 60 }],
    group: 'behavioral'
  },
  {
    id: 'idle_10s',
    label: 'Idle for 10s',
    description: 'User stalls on page — great for “still deciding?” nudges.',
    dom: 'idle',
    command: ['simulateIdle', { seconds: 10 }],
    group: 'behavioral'
  },
  {
    id: 'rage_click',
    label: 'Rage click',
    description: 'Rapid-fire clicks flag UI frustration in forms or support flows.',
    dom: 'rage-click',
    command: ['simulateRageClick'],
    group: 'support'
  },
  {
    id: 'journey_cart_abandon',
    label: 'Checkout drop-off',
    description: 'Adds items, finishes shipping, then hesitates at payment — prime for rescue surveys.',
    dom: 'journey-checkout',
    command: ['simulateCheckoutAbandon'],
    group: 'journeys'
  },
  {
    id: 'journey_return_visit',
    label: 'Returning visitor',
    description: 'Third visit this week with pricing dwell — perfect for re-engagement or loyalty research.',
    dom: 'journey-return',
    command: ['simulateReturningVisitor'],
    group: 'lifecycle'
  },
  {
    id: 'journey_pricing_hesitation',
    label: 'Pricing hesitation',
    description: 'Toggles plans, scrolls between tiers, pauses on comparison table — high-value intent with doubt.',
    dom: 'journey-pricing',
    command: ['simulatePricingHesitation'],
    group: 'journeys'
  },
  {
    id: 'journey_support_struggle',
    label: 'Support struggle',
    description: 'Multiple zero-result searches and a rage click — time to intercept with concierge support.',
    dom: 'journey-support',
    command: ['simulateSupportFrustration'],
    group: 'support'
  }
];

export function findTrigger(triggerId) {
  return TRIGGER_CONFIG.find((item) => item.id === triggerId) || null;
}
