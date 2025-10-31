account = Account.create(name: "My First Account")
user = User.create(first_name: 'pulse', last_name: 'insights', email: 'pi@pi.com', password: 'abcD123$%', account: account)
device = Device.create(udid: '40f8b3f0-efb9-4096-9df9-1f202bbf1f7a') # random udid
image = AnswerImage.create(imageable: account)

5.times do |n|
  survey = account.surveys.create(name: "survey_#{n}")
  submission = survey.submissions.create(device: device)
  question = survey.questions.create(content: "How big is #{n}?")
  possible_answer = question.possible_answers.create(content: "possible_answer_#{n}", answer_image: image)

  account.survey_tags.create(name: "survey_tag_#{n}")
  Theme.create(name: "theme_#{n}", account: account)
  question.answers.create(text_answer: "answer_#{n}", possible_answer: possible_answer, submission: submission)
  question.tags.create(name: "tag_#{n}", color: %w(red blue black).sample)
end
