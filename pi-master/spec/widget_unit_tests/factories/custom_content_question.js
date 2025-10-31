import {questionFactory} from './question';

export const customContentQuestionFactory = questionFactory.params({
  question_type: 'custom_content_question',
  fullscreen: null,
  background_color: '',
  opacity: null,
  autoclose_enabled: null,
  autoclose_delay: null,
  autoredirect_enabled: false,
  autoredirect_delay: null,
  autoredirect_url: '',
});

