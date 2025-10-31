import {questionFactory} from './question';

export const freeTextQuestionFactory = questionFactory.params({
  question_type: 'free_text_question',
  content: 'new free text question',
  height: 1,
  hint_text: '',
  error_text: 'Oops, looks like you are trying to submit personal information!',
  max_length: 141,
  next_question_id: 0,
});

