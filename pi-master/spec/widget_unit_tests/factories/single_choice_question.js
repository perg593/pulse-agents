import {questionFactory} from './question';
import {possibleAnswerFactory} from './possible_answer';

export const singleChoiceQuestionFactory = questionFactory.params({
  question_type: 'single_choice_question',
  content: 'new single choice question',
  possible_answers: possibleAnswerFactory.buildList(2),
});

