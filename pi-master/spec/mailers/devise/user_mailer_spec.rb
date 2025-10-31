# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Devise::UserMailer do
  describe "#reset_password_instructions" do
    let(:user) { create(:user) }
    let(:reset_password_token) { SecureRandom.hex(32) }
    let(:mail) { described_class.reset_password_instructions(user, reset_password_token) }

    it 'has the correct recipient' do
      expect(mail.to.count).to eq 1
      expect(mail.to).to contain_exactly user.email
    end
  end
end
