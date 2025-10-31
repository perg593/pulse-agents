//= require patched_ouibounce
//= require patched_purify.min
//= require surveys/mixins
//= require surveys/main
//= require surveys/survey
//= require surveys/single_page_app
//= require_tree ./surveys
//= stub surveys/callback
//= stub surveys/custom_data_snippet

if (typeof(window.PulseInsightsObject)=='object') {
    // Pulse Insights has already been loaded
} else {
    window.PulseInsightsObject = new window.PulseInsights();
    window.PulseInsightsInclude.initializeSinglePageApp();
}
