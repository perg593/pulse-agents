# frozen_string_literal: true
require 'spec_helper'

describe Account do
  before do
    described_class.delete_all
  end

  let(:account) { create(:account) }

  describe 'validation' do
    subject { account.valid? }

    context 'when name is nil' do
      let(:account) { build(:account, name: nil) }

      it { is_expected.to be false }
    end

    context 'when name is empty' do
      let(:account) { build(:account, name: '') }

      it { is_expected.to be false }
    end

    context 'when name is only whitespace' do
      let(:account) { build(:account, name: ' ') }

      it { is_expected.to be false }
    end

    describe 'domains_to_allow_for_redirection' do
      subject { account.valid? }

      before do
        account.domains_to_allow_for_redirection = allowed_domains
      end

      context 'when there is a white space in a domain' do
        let(:allowed_domains) { ['tes t.com'] }

        it { is_expected.to be false }
      end

      context 'when there is an underscore in a domain' do
        let(:allowed_domains) { ['tes_t.com'] }

        it { is_expected.to be false }
      end

      context 'when there is a comma in a domain' do
        let(:allowed_domains) { ['tes,t.com'] }

        it { is_expected.to be false }
      end

      context 'when there is no invalid character in a domain' do
        let(:allowed_domains) { ['test.com'] }

        it { is_expected.to be true }
      end
    end
  end

  describe "tag_js_version validation" do
    subject { described_class.new }

    it { is_expected.to validate_inclusion_of(:tag_js_version).in_array(TagJsFileHelpers.tag_js_versions) }
  end

  it "is able to create an account" do
    expect(account.valid?).to be true
    expect(described_class.count).to eq(1)
  end

  it "has an ID automatically assigned" do
    expect(account.identifier).not_to be_nil
    expect(account.identifier.size).to eq(11)
    expect(account.identifier).to start_with("PI-")
  end

  it "is able to get the account tag code" do
    expect(account.tag_code).to include("<script>")
    expect(account.tag_code).to include(account.identifier)
  end

  describe "IdP (Identity Provider)" do
    context "when the account belongs to Comcast" do
      before do
        account.update(id: Account::COMCAST_ACCOUNT_ID)
      end

      it "has IdP set up" do
        expect(account.idp_set_up?).to be true
      end
    end

    context "when the account does not belong to Comcast" do
      before do
        account.update(id: 1)
      end

      it "does not have IdP set up" do
        expect(account.idp_set_up?).to be false
      end
    end
  end

  describe 'login_count' do
    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }

    before do
      5.times { create(:signin_activity, account: account, user: user) }
      5.times { create(:signin_activity, account: account, user: user, sudoer_id: 100) }
    end

    context 'when only_external is false' do
      it 'considers the entire sign-in history' do
        expect(account.login_count).to eq 10
      end
    end

    context 'when only_external is true' do
      it "excludes sign-ins coming from @pulseinsights.com or 'LoginAs'" do
        5.times { |n| create(:signin_activity, account: account, user: create(:user, email: "test#{n}@pulseinsights.com")) }
        expect(account.login_count(only_external: true)).to eq 5
      end
    end
  end

  describe "QrveyUser" do
    it "does not create a QrveyUser after its own creation" do
      expect(account.qrvey_user).not_to be_present
    end
  end

  describe "#register_with_qrvey" do
    before do
      account.register_with_qrvey
    end

    it "creates a QrveyUser" do
      expect(QrveyUser.count).to eq(1)
    end

    it "the QrveyUser is associated with the account" do
      expect(account).to have_one(:qrvey_user)
    end

    context "when it is called a second time" do
      before do
        account.register_with_qrvey
      end

      it "does not create another QrveyUser" do
        expect(QrveyUser.count).to eq(1)
      end
    end
  end
end
