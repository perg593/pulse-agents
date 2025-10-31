import {waitForSurvey} from '../widget_test_helpers.js';

import {singleChoiceQuestionFactory} from "./factories/single_choice_question";
import {multipleChoiceQuestionFactory} from "./factories/multiple_choice_question";
import {customContentQuestionFactory} from "./factories/custom_content_question";
import {possibleAnswerFactory} from "./factories/possible_answer";

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

describe('onimpression callback', () => {
  describe('defined through "pi" function', () => {
    beforeEach (() => {
      window.onimpression_called = false;
      PulseInsightsObject.onimpression((_survey) => window.called_onimpression = true);
    });

    test('triggered when a survey is rendered', async () => {
      const survey = {
        survey_type: 0, // docked survey
        inline_target_position: '0', // bottom
        questions: [singleChoiceQuestionFactory.build()],
      };

      PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      expect(window.called_onimpression).toBe(true);
    });

    test('triggered on subsequent survey renderings', async () => {
      const survey = {
        survey_type: 0, // docked survey
        inline_target_position: '0', // bottom
        questions: [singleChoiceQuestionFactory.build()],
      };

      PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      expect(window.called_onimpression).toBe(true);

      // Tear it down and render it again
      window.PulseInsightsObject.survey.tearDownWidget();

      window.called_onimpression = false;

      PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      expect(window.called_onimpression).toBe(true);
    });
  });
});

describe('onview callback', () => {
  describe('defined through "pi" function', () => {
    beforeEach (() => {
      window.onview_called = false;
      PulseInsightsObject.onview((_survey) => window.called_onview = true);
    });

    test('triggered when a survey is viewed', async () => {
      const survey = {
        survey_type: 0, // docked survey
        inline_target_position: '0', // bottom
        questions: [singleChoiceQuestionFactory.build()],
      };

      PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      // TODO: Find a way to test scrolling and IntersectionObserver
      PulseInsightsObject.triggerOnViewCallback();

      expect(window.called_onview).toBe(true);
    });

    test('triggered on subsequent survey viewings', async () => {
      const survey = {
        survey_type: 0, // docked survey
        inline_target_position: '0', // bottom
        questions: [singleChoiceQuestionFactory.build()],
      };

      PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      // TODO: Find a way to test scrolling and IntersectionObserver
      PulseInsightsObject.triggerOnViewCallback();

      expect(window.called_onview).toBe(true);

      // Tear it down and render it again
      window.PulseInsightsObject.survey.tearDownWidget();

      window.called_onview = false;

      PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      // TODO: Find a way to test scrolling and IntersectionObserver
      PulseInsightsObject.triggerOnViewCallback();

      expect(window.called_onview).toBe(true);
    });
  });
});

/*
 * When an oncomplete callback is defined
 * when the survey has at least one answer
 * when the survey is closed
 * calls the oncomplete callback
*/
describe('oncomplete callback', () => {
  test('defined in console', async () => {
    const singleChoiceQuestion = singleChoiceQuestionFactory.build();
    singleChoiceQuestion.id = 1;
    singleChoiceQuestion.possible_answers[0].next_question_id = 2;

    const otherSingleChoiceQuestion = singleChoiceQuestionFactory.build();
    singleChoiceQuestion.id = 2;

    // This variable needs to be accessible to the widget
    // so that the callback can toggle it
    window.oncomplete_called = false;

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [singleChoiceQuestion, otherSingleChoiceQuestion],
      oncomplete_callback_code: 'window.oncomplete_called = true;',
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    // Don't want to call any servers
    window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
      window.PulseInsightsObject.survey.answersSubmitted();
    });

    const singleChoicePossibleAnswer = document.querySelector('._pi_answers_container li a label');
    singleChoicePossibleAnswer.click();

    document.getElementsByClassName('_pi_closeButton')[0].click();

    expect(window.oncomplete_called).toBe(true);
  });

  describe('defined through "pi" function', () => {
    beforeEach (() => {
      window.oncomplete_called = false;
    });

    test('triggered upon completing the survey', async () => {
      const singleChoiceQuestion = singleChoiceQuestionFactory.build();

      const survey = {
        survey_type: 0, // docked survey
        inline_target_position: '0', // bottom
        questions: [singleChoiceQuestion],
      };

      PulseInsightsObject.oncomplete((_survey) => window.called_oncomplete = true);

      PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      // Don't want to call any servers
      window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
        window.PulseInsightsObject.survey.answersSubmitted();
      });

      const singleChoicePossibleAnswer = document.querySelector('._pi_answers_container li a label');
      singleChoicePossibleAnswer.click();

      expect(window.called_oncomplete).toBe(true);
    });

    test('trigger on subsequent completion', async () => {
      const singleChoiceQuestion = singleChoiceQuestionFactory.build();

      const survey = {
        survey_type: 0, // docked survey
        inline_target_position: '0', // bottom
        questions: [singleChoiceQuestion],
      };

      PulseInsightsObject.oncomplete((_survey) => window.called_oncomplete = true);

      PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      // Don't want to call any servers
      window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
        window.PulseInsightsObject.survey.answersSubmitted();
      });

      let singleChoicePossibleAnswer = document.querySelector('._pi_answers_container li a label');
      singleChoicePossibleAnswer.click();

      expect(window.called_oncomplete).toBe(true);

      window.called_oncomplete = undefined;

      PulseInsightsObject.renderSurvey(survey);
      await waitForSurvey();

      // Don't want to call any servers
      window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
        window.PulseInsightsObject.survey.answersSubmitted();
      });

      singleChoicePossibleAnswer = document.querySelector('._pi_answers_container li a label');
      singleChoicePossibleAnswer.click();

      expect(window.called_oncomplete).toBe(true);
    });
  });
});

// When an onclose callback is defined
// and an oncomplete callback is defined
// when the survey has at least one answer
// and the close button is pressed
// the onclose callback is called
// the oncomplete callback is not
test('onclose callback', async () => {
  const singleChoiceQuestion = singleChoiceQuestionFactory.build();
  singleChoiceQuestion.id = 1;
  singleChoiceQuestion.possible_answers[0].next_question_id = 2;

  const otherSingleChoiceQuestion = singleChoiceQuestionFactory.build();
  singleChoiceQuestion.id = 2;

  // These variables need to be accessible to the widget
  // so that the callbacks can toggle them
  window.onclose_called = false;
  window.oncomplete_called = false;

  const survey = {
    survey_type: 0, // docked survey
    inline_target_position: '0', // bottom
    questions: [singleChoiceQuestion, otherSingleChoiceQuestion],
    onclose_callback_code: 'window.onclose_called = true;',
    oncomplete_callback_code: 'window.oncomplete_called = true;',
  };

  window.PulseInsightsObject.renderSurvey(survey);

  await waitForSurvey();

  // Don't want to call any servers
  window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
    window.PulseInsightsObject.survey.answersSubmitted();
  });

  const singleChoicePossibleAnswer = document.querySelector('._pi_answers_container li a label');
  singleChoicePossibleAnswer.click();

  document.getElementsByClassName('_pi_closeButton')[0].click();

  expect(window.onclose_called).toBe(true);
  expect(window.oncomplete_called).toBe(false);
});

// onclose, onanswer, and onclick callbacks have access to an event object
describe('Callbacks with access to an event object', () => {
  const baseSurvey = {
    survey_type: 0, // docked survey
    inline_target_position: '0', // bottom
  };

  const clickCloseButton = () => {
    document.getElementsByClassName('_pi_closeButton')[0].click();
  };

  describe('"onclose" callback', () => {
    const singleChoiceQuestion = singleChoiceQuestionFactory.build();
    const survey = {...baseSurvey, questions: [singleChoiceQuestion]};

    describe('defined through Console', () => {
      test('triggered upon clicking the close button', async () => {
        survey.onclose_callback_code = 'window.event_object_text = event.target.innerHTML';

        window.PulseInsightsObject.renderSurvey(survey);
        await waitForSurvey();

        clickCloseButton();

        expect(window.event_object_text).toBe('×');
      });
    });

    describe('defined through "pi" function', () => {
      test('triggered upon clicking the close button', async () => {
        PulseInsightsObject.onclose((_survey, event) => window.event_object_text = event.target.innerHTML);

        PulseInsightsObject.renderSurvey(survey);
        await waitForSurvey();

        clickCloseButton();

        expect(window.event_object_text).toBe('×');
      });

      test('trigger on subsequent close', async () => {
        PulseInsightsObject.onclose((_survey, event) => window.event_object_text = event.target.innerHTML);

        PulseInsightsObject.renderSurvey(survey);
        await waitForSurvey();

        clickCloseButton();

        expect(window.event_object_text).toBe('×');

        window.event_object_text = undefined;

        PulseInsightsObject.renderSurvey(survey);
        await waitForSurvey();

        clickCloseButton();

        expect(window.event_object_text).toBe('×');
      });
    });
  });

  describe('"onanswer" callback', () => {
    const singleChoiceQuestions = singleChoiceQuestionFactory.buildList(2);

    const firstSingleChoiceQuestion = singleChoiceQuestions[0];
    firstSingleChoiceQuestion.possible_answers = possibleAnswerFactory.buildList(2);

    const secondSingleChoiceQuestion = singleChoiceQuestions[1];

    secondSingleChoiceQuestion.possible_answers[0].content = 'Second Question First Possible Answer';

    firstSingleChoiceQuestion.possible_answers[0].next_question_id = secondSingleChoiceQuestion.id;

    const survey = {...baseSurvey, questions: singleChoiceQuestions};

    // Don't want to call any servers
    window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
      window.PulseInsightsObject.survey.answersSubmitted();
    });

    const clickAnswer = () => { // Clicking one of the possible answers
      document.querySelector('._pi_answers_container li a label').click();
    };

    describe('defined through Console', () => {
      test('triggered upon clicking an answer', async () => {
        const surveyWithCallback = {...survey};
        surveyWithCallback.onanswer_callback_code = 'window.event_object_text = event.target.innerHTML';

        window.PulseInsightsObject.renderSurvey(surveyWithCallback);
        await waitForSurvey();

        clickAnswer();

        expect(window.event_object_text).toBe(firstSingleChoiceQuestion.possible_answers[0].content);
      });
    });

    describe('defined through "pi" function', () => {
      beforeEach(() => {
        PulseInsightsObject.onanswer((_survey, event) => window.event_object_text = event.target.innerHTML);
      });

      test('triggered upon clicking an answer', async () => {
        PulseInsightsObject.renderSurvey(survey);
        await waitForSurvey();

        clickAnswer();

        expect(window.event_object_text).toBe(firstSingleChoiceQuestion.possible_answers[0].content);
      });

      test('triggered upon clicking subsequent answers', async () => {
        PulseInsightsObject.renderSurvey(survey);
        await waitForSurvey();

        clickAnswer();

        expect(window.event_object_text).toBe(firstSingleChoiceQuestion.possible_answers[0].content);
        window.event_object_text = undefined;

        clickAnswer();

        expect(window.event_object_text).toBe(secondSingleChoiceQuestion.possible_answers[0].content);
      });
    });
  });

  describe('"onclick" callback', () => {
    const customContentQuestion = customContentQuestionFactory.build();
    const customContentLinkText = 'test link';
    customContentQuestion.content = `<a href=test.com>${customContentLinkText}</a>`;

    const survey = {
      ...baseSurvey,
      questions: [customContentQuestion],
      custom_content_link_click_enabled: 't',
    };

    const clickLink = () => { // Clicking one of the links in the custom content
      document.querySelector('._pi_question_custom_content_question a').click();
    };

    describe('defined through Console', () => {
      test('triggered upon clicking a link', async () => {
        const surveyWithCallback = {
          ...survey,
          onclick_callback_code: 'window.event_object_text = event.target.innerHTML',
        };

        window.PulseInsightsObject.renderSurvey(surveyWithCallback);
        await waitForSurvey();

        clickLink();

        expect(window.event_object_text).toBe(customContentLinkText);
      });
    });

    describe('defined through "pi" function', () => {
      beforeEach(() => {
        window.event_object_text = undefined;
        PulseInsightsObject.onclick((_survey, event) => window.event_object_text = event.target.innerHTML);
      });

      test('triggered upon clicking a link', async () => {
        PulseInsightsObject.renderSurvey(survey);
        await waitForSurvey();

        clickLink();

        expect(window.event_object_text).toBe(customContentLinkText);
      });

      test('triggered on subsequent clicks', async () => {
        PulseInsightsObject.renderSurvey(survey);
        await waitForSurvey();

        clickLink();

        expect(window.event_object_text).toBe(customContentLinkText);

        window.event_object_text = undefined;

        clickLink();

        expect(window.event_object_text).toBe(customContentLinkText);
      });
    });
  });
});
