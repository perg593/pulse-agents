import {waitForSurvey} from '../widget_test_helpers.js';

import {multipleChoiceQuestionFactory} from "./factories/multiple_choice_question";
import {possibleAnswerFactory} from "./factories/possible_answer";

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

describe('Multiple Choice Question', () => {
  /**
   * Get the submit button element
   *
   * @return { HTMLElement }
   **/
  function getSubmitButtonElement() {
    return document.getElementsByClassName('_pi_multiple_choices_question_submit_button')[0];
  }

  /**
   * Click the submit button
   **/
  function clickSubmitButton() {
    getSubmitButtonElement().click();
  }

  /**
   * Selects all possible answers
   **/
  function selectAllPossibleAnswers() {
    const possibleAnswerElements = document.querySelectorAll('._pi_answers_container label');

    possibleAnswerElements.forEach((possibleAnswerElement) => {
      possibleAnswerElement.click();
    });
  }

  /**
   * Get the error message element that shows when too many
   * possible answers have been selected
   *
   * @return { HTMLElement }
   **/
  function getTooManySelectedErrorElement() {
    return document.getElementsByClassName('_pi_multiple_choices_count')[0];
  }

  /**
   * Get the error message element that shows when no
   * possible answers have been selected
   *
   * @return { HTMLElement }
   **/
  function getNoneSelectedErrorElement() {
    return document.getElementsByClassName('_pi_multiple_choices_question_submit_error')[0];
  }

  test('Custom error message when too many possible answers have been selected', async () => {
    const question = multipleChoiceQuestionFactory.build();
    question.maximum_selection = 2;
    question.maximum_selections_exceeded_error_text = "YOU PICKED TOO MANY!!!";
    question.possible_answers = possibleAnswerFactory.buildList(3);

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [question],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    selectAllPossibleAnswers();

    clickSubmitButton();

    expect(getTooManySelectedErrorElement().innerHTML).toBe(question.maximum_selections_exceeded_error_text);
  });

  test('Aria labels when too many possible answers have been selected', async () => {
    const question = multipleChoiceQuestionFactory.build();
    question.maximum_selection = 2;
    question.possible_answers = possibleAnswerFactory.buildList(3);

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [question],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    selectAllPossibleAnswers();

    clickSubmitButton();

    expect(getSubmitButtonElement().getAttribute('aria-disabled')).toBe('true');
    expect(getTooManySelectedErrorElement().getAttribute('role')).toBe('alert');
  });

  test('Show error message when empty', async () => {
    const emptyErrorMessage = 'Nothing provided';

    const question = multipleChoiceQuestionFactory.build();
    question.empty_error_text = emptyErrorMessage;

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [question],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    clickSubmitButton();

    // confirm that specified error message shows up
    expect(getNoneSelectedErrorElement().innerHTML).toBe(emptyErrorMessage);
  });
});
