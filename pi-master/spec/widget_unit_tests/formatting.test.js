import {
  getQuestionElementById, waitUntil, waitForSurvey,
} from '../widget_test_helpers.js';

import {singleChoiceQuestionFactory} from "./factories/single_choice_question";
import {npsQuestionFactory} from "./factories/nps_question";
import {multipleChoiceQuestionFactory} from "./factories/multiple_choice_question";
import {freeTextQuestionFactory} from "./factories/free_text_question";

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

describe('Unit testing', () => {
  test('Bold text formatting', () => {
    const textToFormat = 'Some *bold* text';

    expect(window.PulseInsightsLibrary.formatText(textToFormat)).
        toBe('Some <b>bold</b> text');
  });

  test('Italicized text formatting', () => {
    const textToFormat = 'Some _italicized_ text';

    expect(window.PulseInsightsLibrary.formatText(textToFormat)).
        toBe('Some <em>italicized</em> text');
  });

  test('Superscript text formatting', () => {
    const textToFormat = 'Some ^superscript^ text';

    expect(window.PulseInsightsLibrary.formatText(textToFormat)).
        toBe('Some <sup>superscript</sup> text');
  });

  test('Subscript text formatting', () => {
    const textToFormat = 'Some ~subscript~ text';

    expect(window.PulseInsightsLibrary.formatText(textToFormat)).
        toBe('Some <sub>subscript</sub> text');
  });
});

describe('Integration testing', () => {
  const mockedContent = 'some fake formatted content';

  beforeEach(() => {
    window.PulseInsightsLibrary.formatText = jest.fn((input) => {
      return mockedContent;
    });
  });

  test('Poll results formatting', async () => {
    const singleChoiceQuestion = singleChoiceQuestionFactory.build();

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [singleChoiceQuestion],
      invitation: null,
      poll_enabled: true,
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const answerResponseData = [
      {
        id: '37',
        content: 'Answer 1',
        count: 2028,
      },
      {
        id: '38',
        content: 'Answer 2',
        count: 1979,
      },
    ];

    // Don't want to call any servers
    window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
      // The callback we're looking for
      window.PulseInsightsObject.survey.answersSubmitted(answerResponseData);
    });

    const possibleAnswerElements = document.querySelectorAll('._pi_answers_container label');

    possibleAnswerElements[0].click();

    // Confirm that the poll result text is replaced with
    // output provided by the text formatter
    const possibleAnswerResultElements = document.querySelectorAll('._pi_pollName');
    expect(possibleAnswerResultElements.length).toBe(singleChoiceQuestion.possible_answers.length);

    possibleAnswerResultElements.forEach((possibleAnswerResultElement) => {
      expect(possibleAnswerResultElement.innerHTML).toBe(mockedContent);
    });
  });

  test('Thank you text formatting', async () => {
    const singleChoiceQuestion = singleChoiceQuestionFactory.build();
    const unformattedThankYouMessage = 'Thank you *very* much';

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      thank_you: unformattedThankYouMessage,
      questions: [singleChoiceQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    // Don't want to call any servers
    window.PulseInsightsObject.jsonpGet = jest.fn((input) => {
      // The callback we're looking for
      window.PulseInsightsObject.survey.answersSubmitted();
    });

    // Find the possible answer and click it
    // Trigger the thank you message by replying to a question
    const possibleAnswerElements = document.querySelectorAll('._pi_answers_container label');
    possibleAnswerElements[0].click();

    // Might take a sec for the click to be processed
    await waitUntil(() => {
      return document.getElementsByClassName('_pi_thankYouSurvey').length !== 0;
    }, 1000);
    // We should now see the thank you message at the end of the survey

    // Confirm that the text formatter was called
    expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(unformattedThankYouMessage);

    const thankYouElement = document.getElementsByClassName('_pi_thankYouSurvey')[0];

    // Confirm that the "thank you" text is replaced with
    // output provided by the text formatter
    expect(thankYouElement.innerHTML).toBe(mockedContent);
  });

  test('NPS question text formatting', async () => {
    const npsQuestion = npsQuestionFactory.build();

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [npsQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const npsQuestionElement = getQuestionElementById(npsQuestion.id);

    // Confirm that the text formatter was called
    expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(npsQuestion.content);

    // Confirm that the possible answer content is replaced with
    // output provided by the text formatter
    expect(npsQuestionElement.innerHTML).toBe(mockedContent);

    const possibleAnswerElements = document.querySelectorAll('._pi_answers_container label');
    expect(possibleAnswerElements.length).toBe(npsQuestion.possible_answers.length);

    possibleAnswerElements.forEach((possibleAnswer, i) => {
      expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(npsQuestion.possible_answers[i].content);
      expect(possibleAnswer.innerHTML).toBe(mockedContent);
    });
  });

  test('Multiple choice question text formatting', async () => {
    const multipleChoiceQuestion = multipleChoiceQuestionFactory.build();

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [multipleChoiceQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const multipleChoiceQuestionElement = getQuestionElementById(multipleChoiceQuestion.id);

    // Confirm that the text formatter was called
    expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(multipleChoiceQuestion.content);

    // Confirm that the possible answer content is replaced with
    // output provided by the text formatter
    expect(multipleChoiceQuestionElement.innerHTML).toBe(mockedContent);

    const possibleAnswerElements = document.querySelectorAll('._pi_answers_container label');
    expect(possibleAnswerElements.length).toBe(multipleChoiceQuestion.possible_answers.length);

    possibleAnswerElements.forEach((possibleAnswer, i) => {
      expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(multipleChoiceQuestion.possible_answers[i].content);
      expect(possibleAnswer.textContent).toBe(mockedContent);
    });
  });

  test('Single choice question menu text formatting', async () => {
    const singleChoiceQuestion = singleChoiceQuestionFactory.build();
    singleChoiceQuestion.button_type = 2;

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [singleChoiceQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const singleChoiceQuestionElement = getQuestionElementById(singleChoiceQuestion.id);

    // Confirm that the text formatter was called
    expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(singleChoiceQuestion.content);

    // Confirm that the question content is replaced with
    // output provided by the text formatter
    expect(singleChoiceQuestionElement.innerHTML).toBe(mockedContent);
  });

  test('Single choice question radio text formatting', async () => {
    const singleChoiceQuestion = singleChoiceQuestionFactory.build();
    singleChoiceQuestion.button_type = 0;

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [singleChoiceQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const singleChoiceQuestionElement = getQuestionElementById(singleChoiceQuestion.id);

    // Confirm that the text formatter was called
    expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(singleChoiceQuestion.content);

    // Confirm that the question content is replaced with
    // output provided by the text formatter
    expect(singleChoiceQuestionElement.innerHTML).toBe(mockedContent);

    const possibleAnswerElements = document.querySelectorAll('._pi_answers_container label');
    expect(possibleAnswerElements.length).toBe(singleChoiceQuestion.possible_answers.length);

    possibleAnswerElements.forEach((possibleAnswer, i) => {
      expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(singleChoiceQuestion.possible_answers[i].content);
      expect(possibleAnswer.innerHTML).toBe(mockedContent);
    });
  });

  test('Single choice question button text formatting', async () => {
    const singleChoiceQuestion = singleChoiceQuestionFactory.build();
    singleChoiceQuestion.button_type = 1;

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [singleChoiceQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const singleChoiceQuestionElement = getQuestionElementById(singleChoiceQuestion.id);

    // Confirm that the text formatter was called
    expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(singleChoiceQuestion.content);

    // Confirm that the question content is replaced with
    // output provided by the text formatter
    expect(singleChoiceQuestionElement.innerHTML).toBe(mockedContent);

    const possibleAnswerElements = document.querySelectorAll('._pi_answers_container label');
    expect(possibleAnswerElements.length).toBe(singleChoiceQuestion.possible_answers.length);

    possibleAnswerElements.forEach((possibleAnswer, i) => {
      expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(singleChoiceQuestion.possible_answers[i].content);
      expect(possibleAnswer.innerHTML).toBe(mockedContent);
    });
  });

  test('Free text question text formatting', async () => {
    // TODO: Pare this down to the essentials
    const freeTextQuestion = freeTextQuestionFactory.build();

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      questions: [freeTextQuestion],
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    const freeTextQuestionElement = getQuestionElementById(freeTextQuestion.id);

    // Confirm that the text formatter was called
    expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(freeTextQuestion.content);

    // Confirm that the question content is replaced with
    // output provided by the text formatter
    expect(freeTextQuestionElement.innerHTML).toBe(mockedContent);
  });

  test('Invitation text formatting', async () => {
    const invitationText = 'To *boldly* go';

    const survey = {
      survey_type: 0, // docked survey
      inline_target_position: '0', // bottom
      invitation: invitationText,
    };

    window.PulseInsightsObject.renderSurvey(survey);

    await waitForSurvey();

    // Confirm that the text formatter was called
    expect(window.PulseInsightsLibrary.formatText).toHaveBeenCalledWith(invitationText);

    const invitationElement = document.getElementsByClassName('_pi_invitationTextContainer')[0];

    // Confirm that the invitation's text is replaced with
    // output provided by the text formatter
    expect(invitationElement.innerHTML).toBe(mockedContent);
  });
});
