# frozen_string_literal: true
require 'spec_helper'

describe ScheduledReportSurvey do
  describe "validations" do
    describe "#validate_standalone_survey_association" do
      context "when stand-alone survey is associated with scheduled report" do
        it "is valid" do
          account = create(:account)
          scheduled_report = create(:scheduled_report, account: account)
          survey = create(:survey, account: account)

          scheduled_report_survey = described_class.new(scheduled_report: scheduled_report, survey: survey)
          expect(scheduled_report_survey.valid?).to be true
        end
      end

      context "when stand-alone survey is not associated with scheduled report" do
        it "is invalid" do
          scheduled_report_survey = described_class.new(survey: create(:survey))
          expect(scheduled_report_survey.valid?).to be false
        end
      end

      context "when stand-alone survey is associated with survey locale group" do
        it "is invalid" do
          scheduled_report_survey = described_class.new(survey: create(:survey),
                                                        scheduled_report_survey_locale_group: create(:scheduled_report_survey_locale_group))
          expect(scheduled_report_survey.valid?).to be false
        end
      end

      context "when the stand-alone survey does not belong to the same account" do
        it "is invalid" do
          scheduled_report_survey = described_class.new(survey: create(:survey), scheduled_report: create(:scheduled_report))
          expect(scheduled_report_survey.valid?).to be false
        end
      end
    end

    describe "#validate_localized_survey_association" do
      context "when localized survey is associated with survey locale group" do
        it "is valid" do
          localized_survey = create(:localized_survey)
          scheduled_report_survey_group = create(:scheduled_report_survey_locale_group, survey_locale_group: localized_survey.survey_locale_group)
          scheduled_report_survey = described_class.new(survey: localized_survey, scheduled_report_survey_locale_group: scheduled_report_survey_group)

          expect(scheduled_report_survey.valid?).to be true
        end
      end

      context "when localized survey is not associated with survey locale group" do
        it "is invalid" do
          scheduled_report_survey = described_class.new(survey: create(:localized_survey))
          expect(scheduled_report_survey.valid?).to be false
        end
      end

      context "when stand-alone survey is associated with scheduled report" do
        it "is invalid" do
          scheduled_report_survey = described_class.new(survey: create(:localized_survey), scheduled_report: create(:scheduled_report))
          expect(scheduled_report_survey.valid?).to be false
        end
      end

      context "when the survey locale group does not belong to the same account" do
        it "is invalid" do
          localized_survey = create(:localized_survey)
          scheduled_report_survey_group = create(:scheduled_report_survey_locale_group, survey_locale_group: localized_survey.survey_locale_group)
          scheduled_report_survey = described_class.new(survey: create(:localized_survey), scheduled_report_survey_locale_group: scheduled_report_survey_group)

          expect(scheduled_report_survey.valid?).to be false
        end
      end
    end
  end
end
