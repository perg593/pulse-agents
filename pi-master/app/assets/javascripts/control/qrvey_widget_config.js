const qrveyWidgetConfig = document.getElementById('qrvey_widget_config').dataset;

var config = {
  domain: qrveyWidgetConfig.domain,
  qv_token: qrveyWidgetConfig.qvToken,
  hideNavigationTab: true,
};

var smartan = true;

if (qrveyWidgetConfig.dashboardId) {
  config.dashboard_id = qrveyWidgetConfig.dashboardId;
}

if (qrveyWidgetConfig.surveyId) {
  config.userFilters = {
    filters: [
      {
        operator: 'AND',
        expressions: JSON.parse(qrveyWidgetConfig.datasets).map((dataset) => {
          return {
            qrveyid: dataset.id,
            questionid: dataset.survey_id_column_id,
            validationType: 'EQUAL',
            value: parseInt(qrveyWidgetConfig.surveyId),
          };
        }),
      },
    ],
  };
}
