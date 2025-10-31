import {waitForSurvey} from '../widget_test_helpers';
import {singleChoiceQuestionFactory} from "./factories/single_choice_question";

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

describe('Custom CSS', () => {
  const singleChoiceQuestion = singleChoiceQuestionFactory.build();
  const baseSurvey = {
    id: 1,
    survey_type: 0, // docked survey
    inline_target_position: '0', // bottom
    questions: [singleChoiceQuestion],
  };

  describe('when a theme is applied to the survey', () => {
    const themeCSS = '._pi_header { color: black; }';
    const survey = {
      ...baseSurvey,
      theme_css: themeCSS,
    };

    test('renders theme CSS', async () => {
      window.PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      const styleTags = document.querySelectorAll(`.survey-${survey.id}`);

      expect(Array.from(styleTags).some((styleTag) => styleTag.innerHTML.includes(themeCSS))).toBe(true);
    });
  });

  describe('when custom_css is applied to the survey', () => {
    const customCSS = '._pi_header { color: black; }';
    const survey = {
      ...baseSurvey,
      custom_css: customCSS,
    };

    test('renders custom CSS', async () => {
      window.PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      const styleTags = document.querySelectorAll(`.survey-${survey.id}`);

      expect(Array.from(styleTags).some((styleTag) => styleTag.innerHTML.includes(customCSS))).toBe(true);
    });
  });
});
