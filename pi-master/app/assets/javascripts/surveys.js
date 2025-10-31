//= require patched_ouibounce
//= require patched_purify.min
//= require patched_nouislider.min
//= require surveys/mixins
//= require surveys/main
//= require surveys/survey
//= require surveys/single_page_app
//= require_tree ./surveys
//= stub surveys/no_callbacks/callback_no_eval
//= stub surveys/no_callbacks/custom_data_snippet_no_eval

window.PulseInsightsInclude.initialize = function() {
  const url = new URL(window.location);
  const disableWidgetKey = 'disable_widget';
  const disableWidget = ['1', 't', 'true'].includes(url.searchParams.get(disableWidgetKey));

  if (disableWidget) {
    console.debug('suppressing widget -- execute snippet to load new widget');

    url.searchParams.delete(disableWidgetKey);

    window.history.pushState({}, '', url);
    window.PulseInsightsObject = {disableObjectPolling: true};
  } else if (typeof(window.PulseInsightsObject)=='object' && !window.PulseInsightsObject.disableObjectPolling) {
    // Pulse Insights has already been loaded
  } else {
    window.PulseInsightsObject = new window.PulseInsights();
    window.PulseInsightsInclude.initializeSinglePageApp();
  }
};

window.PulseInsightsInclude.initialize();
