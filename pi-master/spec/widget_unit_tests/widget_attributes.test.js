import {waitForSurvey} from '../widget_test_helpers.js';

import {singleChoiceQuestionFactory} from './factories/single_choice_question';

import '../../app/assets/javascripts/surveys/inline_survey.coffee';
import '../../app/assets/javascripts/surveys/bar_survey.coffee';
import '../../app/assets/javascripts/surveys/top_bar_survey.coffee';
import '../../app/assets/javascripts/surveys/bottom_bar_survey.coffee';
import '../../app/assets/javascripts/surveys/fullscreen_survey.coffee';

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

describe('survey-widget-type attribute', () => {
  const surveyTypeMapper = {
    docked_widget: 0,
    inline: 1,
    top_bar: 2,
    bottom_bar: 3,
    fullscreen: 4,
  };

  ['docked_widget', 'inline', 'top_bar', 'bottom_bar', 'fullscreen'].forEach((surveyType) => {
    describe(`with ${surveyType}`, () => {
      test(`widget has ${surveyType} in "survey-widget-type" attribute`, async () => {
        const survey = {
          survey_type: surveyTypeMapper[surveyType],
          inline_target_position: '0', // bottom
          inline_target_selector: 'body', // for inline
          pusher_enabled: 'false', // for top_bar
          questions: [singleChoiceQuestionFactory.build()],
        };

        window.PulseInsightsObject.renderSurvey(survey);

        await waitForSurvey();

        const widgetAttributes = document.getElementById('_pi_surveyWidget').attributes;
        const surveyWidgetType = `${surveyType.replace('_', '')}survey`;
        expect(widgetAttributes['survey-widget-type'].value).toBe(surveyWidgetType);
      });
    });
  });
});
