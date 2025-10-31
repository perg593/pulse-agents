# frozen_string_literal: true

# Shared examples for a rack endpoint that implements parameter verification. Checks presence/absence of parameters, not their contents or meaning.
#
# @param {Array of symbols} parameters -- All required parameters
# @param {string} endpoint -- The rack app endpoint to call
require_relative "../../rack/schemas/common_schema"

RSpec.shared_examples "rack parameter verifier" do |parameters, endpoint|
  let(:optional_defaults) { {} }

  parameters.each do |parameter|
    context "when #{parameter} is not provided" do
      before do
        query_parameters = parameters.each_with_object({}) do |param, hash|
          hash[param] = optional_defaults[param] || "placeholder"
          hash
        end
        query_parameters.delete(parameter)

        url = "#{endpoint}?#{query_parameters.to_query}"

        @response = rack_app(url)
      end

      it "returns 400" do
        expect(@response.code).to eq "400"
      end

      it "returns the expected schema" do
        assert_valid_schema RackSchemas::Common::MissingParameterErrorResponse, @response.body
      end

      it "returns an error message" do
        expect(@response.body).to include "Error: Parameter '#{parameter}'"
      end
    end
  end
end
