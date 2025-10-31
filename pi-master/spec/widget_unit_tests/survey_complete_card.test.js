import {waitForSurvey} from '../widget_test_helpers.js';
import {singleChoiceQuestionFactory} from "./factories/single_choice_question";

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

describe('Survey complete card', () => {
  const survey = {
    survey_type: 0, // docked survey
    inline_target_position: '0', // bottom
    questions: [singleChoiceQuestionFactory.build()],
  };

  /**
   * Click the first single choice possible answer
   **/
  function clickFirstSingleChoicePossibleAnswer() {
    const singleChoicePossibleAnswer = document.querySelector('._pi_answers_container li a label');

    singleChoicePossibleAnswer.click();
  }

  /**
   * Get the "thank you" element
   * @return { HTMLElement }
   **/
  function getThankYouElement() {
    const elements = document.getElementsByClassName('_pi_thankYouSurvey');

    return elements.length == 0 ? null : elements[0];
  }

  describe('Thank you card', () => {
    // Don't want to call any servers
    window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
      window.PulseInsightsObject.survey.answersSubmitted();
    });

    test('Default thank you message', async () => {
      window.PulseInsightsObject.renderSurvey(survey);

      await waitForSurvey();

      clickFirstSingleChoicePossibleAnswer();

      expect(getThankYouElement().innerHTML).toBe('Thank you!');
    });

    test('Custom thank you message', async () => {
      const customThankYouMessage = 'Thanks a bunch!';

      survey.thank_you = customThankYouMessage;

      window.PulseInsightsObject.renderSurvey(survey);

      await waitForSurvey();

      clickFirstSingleChoicePossibleAnswer();

      expect(getThankYouElement().innerHTML).toBe(customThankYouMessage);
    });
  });

  test('Poll results', async () => {
    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    // Don't want to call any servers
    window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
      window.PulseInsightsObject.survey.answersSubmitted(['fake', 'poll', 'data']);
    });

    clickFirstSingleChoicePossibleAnswer();

    expect(getThankYouElement()).toBe(null);

    const pollContainerElement = document.getElementsByClassName('_pi_pollContainer');
    expect(pollContainerElement.length).toBe(1);
  });
});
