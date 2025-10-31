# frozen_string_literal: true
require 'spec_helper'

describe Metadata::SurveyMetadatum do
  describe "validations" do
    let(:survey_metadatum) { described_class.new }

    it { expect(survey_metadatum).to validate_presence_of(:name) }
    it { expect(survey_metadatum).to belong_to(:survey).class_name("Survey") }

    context "when another survey in the account has the same metadatum.name" do
      let(:survey_metadatum) { described_class.new(name: "name", survey: create(:survey)) }

      before do
        account = survey_metadatum.survey.account
        create(:survey_metadatum, name: survey_metadatum.name, survey: create(:survey, account: account))
      end

      it "is invalid" do
        expect(survey_metadatum.valid?).to be false
      end
    end

    describe "name" do
      it_behaves_like "s3 object key validation" do
        subject { create(:survey_metadatum) }

        let(:attribute_to_validate) { :name }
      end
    end
  end
end
