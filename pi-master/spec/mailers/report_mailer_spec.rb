# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReportMailer do
  describe "Benjamin Moore monthly report notification" do
    it "sends an e-mail to pulse insights with links" do
      report_url = FFaker::Internet.http_url
      qc_url = FFaker::Internet.http_url

      mail = described_class.benjamin_moore_notification(report_url, qc_url)

      expect(mail.to).to match ["jdippold@pulseinsights.com"]
      expect(mail.subject).to match "Benjamin Moore report links"
      expect(mail.body.raw_source.include?(report_url)).to be true
      expect(mail.body.raw_source.include?(qc_url)).to be true
    end
  end

  describe 'Localization report' do
    context 'when survey group is partially selected in scheduled report' do
      it 'only includes data from selected surveys' do
        survey = create(:localized_survey)
        dup_survey = survey.duplicate
        dup_survey.add_to_localization_group(survey.survey_locale_group.id, 'language_code_dup')

        create(:submission, survey: survey, answers_count: 1).tap do |submission|
          create(:answer, submission: submission, question: survey.questions.first, possible_answer: survey.possible_answers.first)
        end
        create(:submission, survey: dup_survey, answers_count: 1).tap do |submission|
          create(:answer, submission: submission, question: dup_survey.questions.first, possible_answer: dup_survey.possible_answers.first)
        end
        create(:submission, survey: dup_survey, answers_count: 1).tap do |submission|
          create(:answer, submission: submission, question: dup_survey.questions.first, possible_answer: dup_survey.possible_answers.last)
        end

        mail = described_class.localization_report(
          {
            account: survey.account,
            reportee: survey.survey_locale_group,
            reportee_survey_ids: [dup_survey.id]
          }
        )
        expect(mail.body.encoded).to include "50%" # only considering data of "dup_survey"
        expect(mail.body.encoded).not_to include "33%" # considering all surveys in the group
      end
    end
  end
end
