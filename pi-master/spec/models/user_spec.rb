# frozen_string_literal: true
require 'spec_helper'

describe User do
  before do
    described_class.delete_all
    Account.delete_all
    AccountUser.delete_all
  end

  it "is able to create a user" do
    create(:user)
    expect(described_class.count).to eq(1)
  end

  it "is able to have an account" do
    user = create(:user)
    expect(user.account).not_to be_nil
    expect(Account.count).to eq(1)
  end

  describe '#find_by_unfolded_email' do
    context 'when a capitalized email is stored in database' do
      let(:user) { create(:user, email: 'User@test.com') }

      context 'when the input is also capitalized' do
        it 'finds that email' do
          expect(described_class.find_by_unfolded_email(user.email)).to eq user
        end
      end

      context 'when the input is all lower case' do
        it 'finds that email' do
          expect(described_class.find_by_unfolded_email(user.email.downcase)).to eq user
        end
      end
    end

    context 'when an all lower case email is stored in database' do
      let(:user) { create(:user, email: 'user@test.com') }

      context 'when the input is capitalized' do
        it 'finds that email' do
          expect(described_class.find_by_unfolded_email(user.email.capitalize)).to eq user
        end
      end

      context 'when the input is also all lower case' do
        it 'finds that email' do
          expect(described_class.find_by_unfolded_email(user.email)).to eq user
        end
      end
    end
  end

  it "is destroyed only when all of its account links are destroyed" do
    user = create(:user)
    expect(described_class.count).to eq(1)

    account = create(:account)

    AccountUser.create(account_id: account.id, user_id: user.id)

    AccountUser.first.destroy
    expect(described_class.count).to eq(1)

    AccountUser.first.destroy
    expect(described_class.count).to eq(0)
  end

  it "switches accounts automatically if its active account link is destroyed" do
    user = create(:user)
    old_account_id = user.account_id

    new_account = create(:account)
    AccountUser.create(account_id: new_account.id, user_id: user.id)
    expect(user.account_id).to eq(old_account_id)

    user.account.destroy
    user.reload
    expect(user.account_id).to eq(new_account.id)
  end

  it "cannot switch to an unlinked account" do
    user = create(:user)
    old_account_id = user.account_id
    inaccessible_account = create(:account)

    user.switch_accounts(inaccessible_account.id)
    expect(user.account_id).to eq(old_account_id)
  end

  describe "Invitable" do
    subject { user.valid? }

    let(:user) { build(:user) }

    before do
      user.invite_token = invitation&.token
    end

    context "when there is no invitation" do
      let(:invitation) { nil }

      it { is_expected.to be true }
    end

    context "when the invitation is not expired" do
      let(:invitation) { create(:invitation) }

      it { is_expected.to be true }
    end

    context "when the invitation is expired" do
      let(:invitation) { create(:invitation, expires_at: 1.day.ago) }

      it { is_expected.to be false }
    end
  end

  describe "Lockable" do
    let(:user) { create(:user) }

    describe "#lock_access!" do
      it "sets locked_at to the current time" do
        user.lock_access!

        expect(user.locked_at).to be_within(1.second).of(Time.current)
      end

      it "skips validations" do
        user.email = nil

        user.lock_access!

        user.reload

        expect(user.locked_at).to be_within(1.second).of(Time.current)
      end

      context "when a user has SuccessfulMFASignin records" do
        before do
          2.times { create(:successful_mfa_signin, user: user) }
        end

        it "clears the user's SuccessfulMFASignin records" do
          user.lock_access!

          expect(user.successful_mfa_signins.count).to eq(0)
        end
      end
    end

    describe "#unlock_access!" do
      context "when the user has been locked" do
        before do
          user.lock_access!
        end

        it "unlocks the user" do
          user.unlock_access!
          expect(user.access_locked?).to be false
          expect(user.failed_attempts).to eq 0
        end

        it "skips validations" do
          user.email = nil
          user.unlock_access!

          expect(user.access_locked?).to be false
        end
      end
    end

    describe "#access_locked?" do
      context "when the user has been locked" do
        before do
          user.lock_access!
        end

        it "returns true" do
          expect(user.access_locked?).to be true
        end

        context "when the user was locked more than 1 hour ago" do
          before do
            user.update(locked_at: (Time.current - (described_class.unlock_in + 1.minute)))
          end

          it "returns false" do
            expect(user.access_locked?).to be false
          end
        end
      end

      context "when the user has not been locked" do
        it "returns false" do
          expect(user.access_locked?).to be false
        end
      end
    end

    describe "#valid_for_authentication?" do
      context "when the user is not in the database" do
        let(:user) { described_class.new }

        it "returns false" do
          expect(user.valid_for_authentication?).to be false
        end

        it "does not increment failed_attempts" do
          user.valid_for_authentication?
          expect(user.failed_attempts).to eq 0
        end
      end

      context "when the user has been locked" do
        before do
          user.lock_access!
        end

        context "when the user's lock has not expired and the user is invalid" do
          before do
            user.email = nil
            @return_value = user.valid_for_authentication?
          end

          it "returns false" do
            expect(@return_value).to be false
          end

          it "increments failed_attempts" do
            expect(user.failed_attempts).to eq 1
          end
        end

        context "when the user's lock has not expired" do
          before do
            @return_value = user.valid_for_authentication?
          end

          it "returns false" do
            expect(@return_value).to be false
          end

          it "increments failed_attempts" do
            expect(user.failed_attempts).to eq 1
          end
        end

        context "when the user's lock has expired" do
          before do
            user.update(locked_at: (Time.current - described_class.unlock_in))
            @return_value = user.valid_for_authentication?
          end

          it "unlocks the user" do
            expect(user.access_locked?).to be false
          end

          it "returns true" do
            expect(@return_value).to be true
          end

          it "sets failed_attempts to 0" do
            expect(user.failed_attempts).to eq 0
          end
        end
      end

      context "when the user has not been locked" do
        before do
          @return_value = user.valid_for_authentication?
        end

        it "returns true" do
          expect(@return_value).to be true
        end

        it "does not increment failed_attempts" do
          expect(user.failed_attempts).to eq 0
        end
      end
    end
  end

  describe "Recoverable" do
    describe "#self.send_reset_password_instructions" do
      before do
        described_class.send_reset_password_instructions(email: user.email)
      end

      context "with inactive user" do
        let(:user) { create(:user, active: false) }

        it "sends instructions" do
          expect(user.reload.reset_password_token).not_to be_nil
        end
      end

      context "with active user" do
        let(:user) { create(:user, active: true) }

        it "sends instructions" do
          expect(user.reload.reset_password_token).not_to be_nil
        end
      end
    end
  end
end
