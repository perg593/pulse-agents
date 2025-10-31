# frozen_string_literal: true
require 'spec_helper'

describe ApplicationCable::Connection do
  let(:user) { create(:user, last_action_at: Time.current) }

  context "with a verified user" do
    before do
      cookies.signed['user.id'] = user.id
    end

    it "successfully connects" do
      connect "/cable"
      expect(connection.current_user).to eq(user)
    end

    context 'when the user is inactive' do
      before do
        user.update(last_action_at: 31.minutes.ago)
      end

      it "rejects the connection" do
        expect { connect "/cable" }.to have_rejected_connection
      end
    end
  end

  context "with an invalid user id" do
    before do
      cookies.signed['user.id'] = -1
    end

    it "rejects the connection" do
      expect { connect "/cable" }.to have_rejected_connection
    end
  end
end
