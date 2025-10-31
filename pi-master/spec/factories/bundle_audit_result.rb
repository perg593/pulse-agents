# frozen_string_literal: true
FactoryBot.define do
  factory :bundle_audit_result, class: "BundleAudit::Result" do
    gem do
      {
        name: FFaker::Movie.title, version: FFaker::Number.decimal.to_s
      }
    end

    advisory do
      {
        title: FFaker::Lorem.word, url: FFaker::Internet.http_url, patched_versions: [FFaker::Number.decimal], description: FFaker::Lorem.phrase
      }
    end

    initialize_with { new(attributes.deep_stringify_keys) }
  end
end
