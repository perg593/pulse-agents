import {waitForSurvey} from '../widget_test_helpers.js';

import {singleChoiceQuestionFactory} from './factories/single_choice_question';

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

// https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2773#note_1190840
window.DOMPurify = require('../../vendor/assets/javascripts/patched_purify.min');

describe('HTML Sanitization', () => {
  let originalConfirm;

  beforeEach(() => {
    originalConfirm = window.confirm;
    window.confirm = jest.fn();
  });

  afterEach(() => {
    window.confirm = originalConfirm;
  });

  describe('Text Above/Below Question', () => {
    test('Malicious code does not get executed', async () => {
      const singleChoiceQuestion = singleChoiceQuestionFactory.build({
        before_question_text: '<img src=\'\' onerror=confirm()>',
        after_question_text: '<img src=\'\' onerror=confirm()>',
      });

      const survey = {
        survey_type: 0, // docked survey
        inline_target_position: '0', // bottom
        questions: [singleChoiceQuestion],
      };

      window.PulseInsightsObject.renderSurvey(survey);

      await waitForSurvey();

      expect(window.confirm).not.toHaveBeenCalled();
    });
  });
});
