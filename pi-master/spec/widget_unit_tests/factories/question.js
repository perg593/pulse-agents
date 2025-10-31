import {Factory} from 'fishery';

export const questionFactory = Factory.define(({sequence}) => ({
  id: sequence,
  position: 0,
  submit_label: '',
  button_type: 1,
  desktop_width_type: 0,
  answers_alignment_desktop: null,
  answers_per_row_desktop: 3,
  answers_per_row_mobile: 3,
  optional: 'f',
  image_type: null,
  mobile_width_type: 0,
  answers_alignment_mobile: null,
  created_at: 1697868145,
  before_question_text: '',
  after_question_text: '',
  before_answers_count: '',
  after_answers_count: '',
  before_answers_items: null,
  after_answers_items: null,
  nps: null,
  single_choice_default_label: 'Select an option',
  question_locale_group_id: null,
  empty_error_text: 'Required.',
}));

