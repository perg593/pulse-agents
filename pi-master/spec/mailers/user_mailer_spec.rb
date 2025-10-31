# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserMailer do
  describe 'reset_email' do
    let(:current_email) { FFaker::Internet.email }
    let(:new_email) { FFaker::Internet.email }
    let(:reset_email_token) { SecureRandom.hex(10) }

    let(:mail) { described_class.reset_email(current_email, new_email, reset_email_token) }

    it 'has the correct recipient' do
      expect(mail.to.count).to eq 1
      expect(mail.to.first).to eq current_email
    end

    it 'has a confirmation link' do
      expect(CGI.unescapeHTML(mail.body.to_s)).to include edit_email_url(new_email: new_email, reset_email_token: reset_email_token)
    end
  end

  describe 'send_out_invitation' do
    let(:account) { create(:account) }
    let(:invitation) { create(:invitation, account: account, email: FFaker::Internet.email) }
    let(:inviter) { create(:user, account: account) }

    let!(:primary_user) { create(:user, account: account) } # To replicate https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2112

    let(:inviter_email) { inviter.email }

    let(:mail) { described_class.send_out_invitation(invitation) }

    # Testing for the incident https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2112
    it 'is not affected by the current account of the primary user' do
      other_account = create(:account)
      primary_user.accounts << other_account
      primary_user.switch_accounts(other_account.id)

      expect(account.primary_user).to eq primary_user
      expect(primary_user.account).to eq other_account # The current account
      expect(mail.body.to_s).not_to include other_account.name
      expect(mail.body.to_s).not_to include other_account.identifier
    end

    it 'has the correct recipient' do
      expect(mail.to.count).to eq 1
      expect(mail.to.first).to eq invitation.email
    end

    it "does not include the inviter's email" do
      expect(mail.body.to_s).not_to include inviter_email
    end

    it 'has the correct account information' do
      expect(CGI.unescapeHTML(mail.body.to_s)).to include "have been invited to join the Pulse Insights Account #{account.name} (#{account.identifier})."
    end

    it 'has a sign up url with the correct invitee email' do
      expect(mail.body.to_s).to include "/sign_up?#{{ email: invitation.email }.to_query}"
    end
  end

  describe 'locked_notification' do
    let(:mail) { described_class.locked_notification(create(:user), "128.0.0.1") }

    it 'has the correct recipient' do
      expect(mail.to.count).to eq 1
      expect(mail.to.first).to eq 'alerts@pulseinsights.com'
    end
  end

  describe "automation_triggered" do
    let(:emails) { %w(user1@test.com user2@test.com) }
    let(:survey) { create(:survey) }
    let(:question) { survey.questions.first }
    let(:automation_names) { %w(automation1) }
    let(:answer) { create(:answer) }

    let(:mail) { described_class.automation_triggered(emails, survey.name, question.content, automation_names, answer.text_of_response) }

    it "has correct recipients" do
      expect(mail.to).to eq emails
    end

    it 'has the correct survey name' do
      expect(mail.body).to include "Survey: #{survey.name}."
    end

    it 'has the correct question content' do
      expect(mail.body).to include "Question: #{question.content}."
    end

    it 'has the correct answer text' do
      expect(mail.body).to include "Answer: #{answer.text_of_response}."
    end

    context 'when there is only 1 automation' do
      it "tells that there is 1 automation" do
        expect(mail.body).to include '1 of your Automations has'
      end
    end

    context 'when there are 2 automation2' do
      it "tells that there are 2 automations" do
        automation_names << 'automation2'
        expect(mail.body).to include '2 of your Automations have'
      end
    end
  end
end
