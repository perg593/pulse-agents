import {waitForSurvey, waitUntil, getAnswerContainer} from '../widget_test_helpers.js';

import {singleChoiceQuestionFactory} from './factories/single_choice_question';
import {multipleChoiceQuestionFactory} from './factories/multiple_choice_question';
import {freeTextQuestionFactory} from './factories/free_text_question';
import {sliderQuestionFactory} from './factories/slider_question';

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

// https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2773#note_1190840
window.noUiSlider = require('../../vendor/assets/javascripts/patched_nouislider.min');

describe('All At Once Survey', () => {
  describe('When there are more than two questions of each question type', () => {
    test('Answers are accurately recorded and submittable', async () => {
      const singleChoiceQuestions = singleChoiceQuestionFactory.buildList(2);
      const multipleChoiceQuestions = multipleChoiceQuestionFactory.buildList(2);
      const freeTextQuestions = freeTextQuestionFactory.buildList(2);
      const sliderQuestions = sliderQuestionFactory.buildList(2);

      // For rendering
      sliderQuestions.forEach((sliderQuestion) => {
        sliderQuestion.possible_answers.forEach((possibleAnswer, index) => {
          possibleAnswer.position = index;
        });
      });

      const survey = {
        survey_type: 0, // docked survey
        inline_target_position: '0', // bottom
        display_all_questions: 't',
        questions: [
          ...singleChoiceQuestions,
          ...multipleChoiceQuestions,
          ...freeTextQuestions,
          ...sliderQuestions,
        ],
      };

      window.PulseInsightsObject.renderSurvey(survey);

      await waitForSurvey();

      // Don't want to call any servers
      window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
        window.PulseInsightsObject.survey.allAnswersSubmitted();
      });

      singleChoiceQuestions.forEach((singleChoiceQuestion) => {
        const singleChoiceAnswerContainer = getAnswerContainer(singleChoiceQuestion.id);
        const singleChoiceAnswerId = singleChoiceQuestion.possible_answers[0].id.toString();

        singleChoiceAnswerContainer.querySelector(`a[data-answer-id='${singleChoiceAnswerId}'] label`).click();
        expect(singleChoiceAnswerContainer.dataset.answer.includes(singleChoiceAnswerId)).toBe(true);
      });

      multipleChoiceQuestions.forEach((multipleChoiceQuestion) => {
        const multipleChoiceAnswerContainer = getAnswerContainer(multipleChoiceQuestion.id);
        const multipleChoiceAnswerElements = multipleChoiceAnswerContainer.querySelectorAll('input');

        multipleChoiceAnswerElements.forEach((answerElement) => {
          answerElement.click();
          expect(multipleChoiceAnswerContainer.dataset.answer.includes(answerElement.value)).toBe(true);
        });
      });

      freeTextQuestions.forEach((freeTextQuestion, index) => {
        const freeTextAnswerContainer = getAnswerContainer(freeTextQuestion.id);
        const freeTextInput = freeTextAnswerContainer.querySelector('input');

        freeTextInput.value = `${index}`;
        freeTextInput.dispatchEvent(new KeyboardEvent('keyup'));
        expect(freeTextAnswerContainer.dataset.answer.includes(`${index}`)).toBe(true);
      });

      sliderQuestions.forEach((sliderQuestion) => {
        const sliderAnswerContainer = getAnswerContainer(sliderQuestion.id);
        const sliderPip = sliderAnswerContainer.querySelector('.noUi-value');
        const sliderPipId = sliderQuestion.possible_answers.find((possibleAnswer) => {
          return possibleAnswer.position == parseInt(sliderPip.dataset.value);
        }).id;

        sliderPip.click();
        expect(sliderAnswerContainer.dataset.answer.includes(sliderPipId)).toBe(true);
      });

      const allAtOnceSubmitButton = document.querySelector('._pi_all_questions_submit_button');

      const submissionErrorAttribute = allAtOnceSubmitButton.getAttribute('data-submit-error');
      expect(submissionErrorAttribute).toBe(null);

      const submissionErrorMessage = document.querySelector('._pi_all_at_once_submit_error').innerHTML;
      expect(submissionErrorMessage).toBe('');

      allAtOnceSubmitButton.click();

      expect(document.querySelector('._pi_thankYouSurvey')).toBeTruthy();
    });
  });

  test('The survey will not submit when a question has not been answered', async () => {
    const singleChoiceQuestion = singleChoiceQuestionFactory.build();

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      display_all_questions: 't',
      questions: [
        singleChoiceQuestion,
      ],
      all_at_once_error_text: 'Please fill in all answers!',
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    window.PulseInsightsObject.jsonpGet = jest.fn((input) => {});

    const allAtOnceSubmitButton = document.querySelector('._pi_all_questions_submit_button');
    allAtOnceSubmitButton.click();

    // Might take a sec for the click to be processed
    await waitUntil(() => {
      return document.getElementsByClassName('_pi_all_at_once_submit_error').length !== 0;
    }, 1000);

    expect(allAtOnceSubmitButton.getAttribute('data-submit-error')).toBe('true');

    const errorMessageElement = document.querySelector('._pi_all_at_once_submit_error');
    expect(errorMessageElement.innerHTML).toBe(survey.all_at_once_error_text);

    expect(document.querySelector('._pi_thankYouSurvey')).toBe(null);

    expect(window.PulseInsightsObject.jsonpGet).not.toHaveBeenCalled();
  });

  describe('When PDF is enabled', () => {
    beforeEach(() => PulseInsightsObject.designatePdfResults(true));

    test('PDF result is requested', async () => {
      const singleChoiceQuestion = singleChoiceQuestionFactory.build();

      const survey = {
        survey_type: 0, // docked survey
        inline_target_position: '0', // bottom
        display_all_questions: 't',
        questions: [singleChoiceQuestion],
      };

      window.PulseInsightsObject.renderSurvey(survey);

      await waitForSurvey();

      const singleChoiceAnswerContainer = getAnswerContainer(singleChoiceQuestion.id);
      const singleChoiceAnswerId = singleChoiceQuestion.possible_answers[0].id.toString();
      singleChoiceAnswerContainer.querySelector(`a[data-answer-id='${singleChoiceAnswerId}'] label`).click();

      PulseInsightsObject.submission = {udid: '00000000-0000-4000-f000-000000000001'};

      const mockPdfResponse = {blob: jest.fn().mockResolvedValue(new Blob())};
      global.fetch = jest.fn().mockResolvedValue(mockPdfResponse);

      const allAtOnceSubmitButton = document.querySelector('._pi_all_questions_submit_button');
      expect(allAtOnceSubmitButton.disabled).toBe(false);

      allAtOnceSubmitButton.click();
      expect(allAtOnceSubmitButton.disabled).toBe(true);

      await new Promise((resolve) => setTimeout(resolve, 100));
      expect(allAtOnceSubmitButton.disabled).toBe(false);

      const mockPdfRequest = fetch.mock.calls[0][0];
      expect(mockPdfRequest.toString()).toMatch(/pdf_results=true/);
    });
  });
});

