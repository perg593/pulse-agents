import {questionFactory} from './question';
import {possibleAnswerFactory} from './possible_answer';

export const npsQuestionFactory = questionFactory.params({
  question_type: 'single_choice_question',
  content: 'new single choice question',
  single_choice_default_label: 'Select an option',
  possible_answers: possibleAnswerFactory.buildList(2),
  nps: true,
});

