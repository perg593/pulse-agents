# frozen_string_literal: true
require 'spec_helper'

RSpec.describe SigninActivity do
  describe "'for_external_teams' scope" do
    context "when a user signs in from 'LoginAs'" do
      it "is considered 'internal'" do
        expect { create(:signin_activity, sudoer: create(:user)) }.not_to change { described_class.for_external_teams.count }
      end
    end

    context "when a user's email has @pulseinsights.com" do
      it "is considered 'internal'" do
        expect { create(:signin_activity, user: create(:user, email: 'test@pulseinsights.com')) }.not_to change { described_class.for_external_teams.count }
      end
    end

    context "when a user doesn't sign in from 'LoginAs' and doesn't have @pulseinsights.com in their email" do
      it "is considered 'external'" do
        expect { create(:signin_activity) }.to change { described_class.for_external_teams.count }.from(0).to(1)
      end
    end
  end
end
