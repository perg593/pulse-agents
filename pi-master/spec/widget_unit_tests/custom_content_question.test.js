import {waitForSurvey, getAnswerContainer} from '../widget_test_helpers.js';
import {customContentQuestionFactory} from "./factories/custom_content_question";
import {singleChoiceQuestionFactory} from './factories/single_choice_question';

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

// Run tests for different kinds of content
describe('Custom Content Question', () => {
  test.each([
    '<p>Test of custom content features<br></p>',
    '<script>console.debug("I hope this works");</script>',
  ])('renders custom content %p', async (customContent) => {
    const customContentQuestion = customContentQuestionFactory.build();

    customContentQuestion.content = customContent;

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [customContentQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const customContentQuestionElements = document.getElementsByClassName('_pi_question_custom_content_question');
    expect(customContentQuestionElements.length).toBe(1);

    expect(customContentQuestionElements[0].innerHTML).toBe(customContent);
  });
});

describe('Onclick callback', () => {
  test('Toggle window.test_flag', async () => {
    window.test_flag = false;

    const customContentQuestion = customContentQuestionFactory.build();
    customContentQuestion.content = '<a href=test.com>test link</a>';

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [customContentQuestion],
      custom_content_link_click_enabled: 't',
      onclick_callback_code: 'window.test_flag = true;',
    };
    window.PulseInsightsObject.renderSurvey(survey);
    await waitForSurvey();

    const customContentLink = document.querySelector('._pi_question_custom_content_question a');
    customContentLink.click();

    expect(window.test_flag).toBe(true);
  });
});


describe('Thank You replacement flag', () => {
  test('When show_after_aao is true', async () => {
    // It is not rendered with the survey
    const customContentQuestion = customContentQuestionFactory.build();
    customContentQuestion.content = '<a href=test.com>test link</a>';
    customContentQuestion.show_after_aao = true;

    const singleChoiceQuestion = singleChoiceQuestionFactory.build();

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [singleChoiceQuestion, customContentQuestion],
      display_all_questions: 't',
    };

    window.PulseInsightsObject.renderSurvey(survey);
    await waitForSurvey();

    // Don't want to call any servers
    window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
      window.PulseInsightsObject.survey.allAnswersSubmitted();
    });

    // The question is not rendered
    expect(document.querySelector('._pi_question_custom_content_question')).toBe(null);

    // After answering a question
    const singleChoiceAnswerContainer = getAnswerContainer(singleChoiceQuestion.id);
    console.debug(document.body.innerHTML);
    const singleChoiceAnswerId = singleChoiceQuestion.possible_answers[0].id.toString();
    singleChoiceAnswerContainer.querySelector(`a[data-answer-id='${singleChoiceAnswerId}'] label`).click();

    const allAtOnceSubmitButton = document.querySelector('._pi_all_questions_submit_button');
    allAtOnceSubmitButton.click();

    // Now the custom content question should be rendered
    expect(document.querySelector('._pi_question_custom_content_question')).not.toBe(null);
  });
});
