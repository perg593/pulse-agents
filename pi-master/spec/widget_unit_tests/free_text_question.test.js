import {waitForSurvey} from '../widget_test_helpers.js';
import {freeTextQuestionFactory} from "./factories/free_text_question";

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

describe('Free Text Question', () => {
  test('Input limit enforcement', async () => {
    const maxLength = 10;

    const freeTextQuestion =freeTextQuestionFactory.build();
    freeTextQuestion.max_length = maxLength;

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [freeTextQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const freeTextInputElements = document.getElementsByClassName('_pi_free_text_question_field');
    expect(freeTextInputElements.length).toBe(1);

    const input = freeTextInputElements[0];
    expect(input.getAttribute('maxlength')).toBe(maxLength.toString());
  });

  describe('"height" attribute', () => {
    const freeTextQuestion = freeTextQuestionFactory.build();

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [freeTextQuestion],
    };

    describe('when it is set to 1', () => {
      const height = 1;

      beforeEach(() => {
        freeTextQuestion.height = height;
      });

      test('a text input is rendered', async () => {
        window.PulseInsightsObject.renderSurvey(survey);

        await waitForSurvey();

        const freeTextInputElement = document.querySelector('input._pi_free_text_question_field');
        expect(freeTextInputElement).not.toBeNull();
      });
    });

    describe('when it is set to more than 1', () => {
      const height = 10;

      beforeEach(() => {
        freeTextQuestion.height = height;
      });

      test('a textarea is rendered', async () => {
        window.PulseInsightsObject.renderSurvey(survey);

        await waitForSurvey();

        const freeTextInputElement = document.querySelector('textarea._pi_free_text_question_field');
        expect(freeTextInputElement).not.toBeNull();
        expect(freeTextInputElement.rows).toBe(height);
      });
    });
  });
});
