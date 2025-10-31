# frozen_string_literal: true
require 'spec_helper'

describe Admin::MetadataController do
  before do
    sign_in create(:admin)
  end

  describe "POST #create" do
    before do
      survey = create(:survey)
      @name =  FFaker::Lorem.unique.word
      post :create, params: { type: "survey", name: @name, owner_record_id: survey.id }
    end

    it "returns 200" do
      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)

      metadatum = Metadata::Metadatum.first

      expect(json_response).to match_metadatum(metadatum)
    end

    it "creates the metadata" do
      expect(Metadata::Metadatum.count).to eq(1)

      metadatum = Metadata::Metadatum.first

      expect(metadatum.name).to eq(@name)
      expect(metadatum.type).to eq("Metadata::SurveyMetadatum")
    end
  end

  describe "PATCH #update" do
    before do
      @metadatum = create(:survey_metadatum)
      patch :update, params: { id: @metadatum.id, metadatum: { name: "bar" } }
      @metadatum.reload
    end

    it "updates the metadatum" do
      expect(@metadatum.name).to eq("bar")
    end

    it "returns 200" do
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)

      expect(json_response).to match_metadatum(@metadatum)
    end
  end

  describe "DELETE #destroy" do
    context "when passed a valid id" do
      before do
        @metadatum = create(:survey_metadatum, survey: create(:survey))

        delete :destroy, params: { id: @metadatum.id }
      end

      it "returns 200" do
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to match_metadatum(@metadatum)
      end

      it "destroys the metadatum" do
        expect(Metadata::Metadatum.count).to eq(0)
      end
    end
  end

  RSpec::Matchers.define :match_metadatum do |metadatum|
    expected = {
      "id" => metadatum.id,
      "name" => metadatum.name
    }

    match do |json_response|
      expect(json_response).to match(**expected)
    end

    failure_message do |actual|
      "Expected #{actual} to match #{expected}"
    end
  end
end
