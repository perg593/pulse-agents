import '../widget_test_helpers.js';

describe('getParam', () => {
  test('get a parameter', () => {
    const queryString = '?pi_present=100';
    const fullUrl = `https://test.com${queryString}`;

    // Mocking window.location
    delete window.location;
    window.location = {href: fullUrl, search: queryString};

    expect(window.PulseInsightsLibrary.getParam('pi_present')).toBe('100');
  });
});
