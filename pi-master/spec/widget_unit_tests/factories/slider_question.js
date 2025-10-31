import {questionFactory} from './question';
import {possibleAnswerFactory} from './possible_answer';

export const sliderQuestionFactory = questionFactory.params({
  question_type: 'slider_question',
  content: 'this is a slider question',
  slider_start_position: 1,
  slider_submit_button_enabled: 't',
  possible_answers: possibleAnswerFactory.buildList(3),
});
