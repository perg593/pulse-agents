import {getQuestionElementById, waitForSurvey} from '../widget_test_helpers.js';

import {singleChoiceQuestionFactory} from "./factories/single_choice_question";
import {multipleChoiceQuestionFactory} from "./factories/multiple_choice_question";
import {freeTextQuestionFactory} from "./factories/free_text_question";
import {npsQuestionFactory} from "./factories/nps_question";
import {customContentQuestionFactory} from "./factories/custom_content_question";

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

describe('One at a time survey', () => {
  test('Renders the first question and only the first question', async () => {
    const firstQuestion = singleChoiceQuestionFactory.build();
    firstQuestion.id = 1;

    const secondQuestion = singleChoiceQuestionFactory.build();
    secondQuestion.id = 2;

    const survey = {
      survey_type: 0, // docked survey
      display_all_questions: 'f',
      inline_target_position: '0', // bottom
      questions: [firstQuestion, secondQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const firstQuestionElement = getQuestionElementById(firstQuestion.id);
    expect(firstQuestionElement).not.toBe(null);

    const secondQuestionElement = getQuestionElementById(secondQuestion.id);
    expect(secondQuestionElement).toBe(null);
  });
});

describe('All at once survey', () => {
  test('Renders all questions', async () => {
    const questions = [
      singleChoiceQuestionFactory.build(),
      multipleChoiceQuestionFactory.build(),
      freeTextQuestionFactory.build(),
      npsQuestionFactory.build(),
      customContentQuestionFactory.build(),
    ];

    questions.forEach((question, i) => {
      question.id = i;
    });

    const survey = {
      survey_type: 0, // docked survey
      display_all_questions: 't',
      inline_target_position: '0', // bottom
      questions: questions,
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    questions.forEach((question) => {
      const questionElement = getQuestionElementById(question.id);
      expect(questionElement).not.toBe(null);
    });
  });
});
