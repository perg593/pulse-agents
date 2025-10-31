import {waitForSurvey} from '../widget_test_helpers.js';
import {singleChoiceQuestionFactory} from "./factories/single_choice_question";

import '../../app/assets/javascripts/surveys/text_formatting.coffee';

import '../../app/assets/javascripts/surveys/debounce.js';

test('specified invitation text is rendered', async () => {
  const invitationText = 'Welcome to the survey';
  const question = singleChoiceQuestionFactory.build();

  const survey = {
    survey_type: 0, // docked survey
    inline_target_position: '0', // bottom
    questions: [question],
    invitation: invitationText,
  };

  window.PulseInsightsObject.renderSurvey(survey);

  await waitForSurvey();

  const invitationContainerElement = document.getElementsByClassName('_pi_invitationTextContainer')[0];
  expect(invitationContainerElement).not.toBe(undefined);

  expect(invitationContainerElement.innerHTML).toBe(invitationText);

  expect(document.getElementById(`_pi_question_${question.id}`)).toBe(null);
});
