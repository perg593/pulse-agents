import {questionFactory} from './question';
import {possibleAnswerFactory} from './possible_answer';

export const multipleChoiceQuestionFactory = questionFactory.params({
  question_type: 'multiple_choices_question',
  next_question_id: 0,
  possible_answers: possibleAnswerFactory.buildList(2),
});

