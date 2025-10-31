import {Factory} from 'fishery';

export const possibleAnswerFactory = Factory.define(({sequence}) => ({
  id: sequence,
  position: 0,
  content: 'Answer 1',
  next_question_id: 161,
  image_url: null,
  image_alt: null,
  image_width: '',
  image_height: '',
  image_width_mobile: '',
  image_height_mobile: '',
  image_width_tablet: '',
  image_height_tablet: '',
  image_position: null,
  possible_answer_locale_group_id: null,
}));
