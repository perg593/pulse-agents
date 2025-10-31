# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DeveloperNotificationMailer do
  describe "bundle_audit_vulnerabilities_detected" do
    context "with results" do
      let(:results) do
        [build(:bundle_audit_result)] * 2
      end

      let(:mail) { described_class.bundle_audit_vulnerabilities_detected(results) }

      it "goes to the right people" do
        expect(mail.to.count).to eq 1
        expect(mail.to.first).to eq "dev.pulseinsights@ekohe.com"
      end

      it "includes results" do
        results.each do |result|
          [result.title, result.url, result.description, result.gem_name, result.our_gem_version, result.patched_versions].each do |attribute|
            expect(attribute).not_to be_nil
            expect(mail.body.to_s).to include attribute
          end
        end
      end
    end
  end

  describe "yarn_audit_vulnerabilities_detected" do
    context "with results" do
      let(:results) { {"something" => "not_sure_yet"} }

      let(:mail) { described_class.yarn_audit_vulnerabilities_detected(results) }

      it "goes to the right people" do
        expect(mail.to.count).to eq 1
        expect(mail.to.first).to eq "dev.pulseinsights@ekohe.com"
      end

      it "includes results" do
        expect(mail.body.to_s).to include "something"
        expect(mail.body.to_s).to include "not_sure_yet"
      end
    end
  end
end
