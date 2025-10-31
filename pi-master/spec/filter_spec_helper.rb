# frozen_string_literal: true

# Creates records necessary for a possible answer filter test
# i.e. a test where we limit results to all submissions which included an answer
# that included the target possible answer
#
# @param { Survey } survey -- the survey to create records for
# @param { Integer } possible_answer_id -- the ID of the possible answer to filter on
#
# @return { Submission } the submission record targeted by the filter
def make_possible_answer_filter_records(survey, possible_answer_id)
  target_question = survey.questions[0]
  other_question = survey.questions[1]

  target_possible_answer = create(:possible_answer, id: possible_answer_id, question: target_question)
  target_submission = create(:submission, survey: survey, created_at: survey.account.viewed_impressions_enabled_at, viewed_at: FFaker::Time.datetime)

  # One for this possible answer -- INCLUDED
  create(:answer, submission: target_submission, possible_answer: target_possible_answer, question: target_question)

  # One for a different possible answer in the same submission -- INCLUDED
  other_possible_answer = create(:possible_answer, question: other_question)

  create(:answer, submission: target_submission, possible_answer: other_possible_answer, question: other_question)

  # One for a different possible answer in a different submission -- EXCLUDED
  random_submission = create(:submission, survey: survey, created_at: survey.account.viewed_impressions_enabled_at, viewed_at: FFaker::Time.datetime)
  ignored_possible_answer = create(:possible_answer, question: other_question)
  create(:answer, submission: random_submission, possible_answer: ignored_possible_answer, question: other_question)

  target_submission
end
