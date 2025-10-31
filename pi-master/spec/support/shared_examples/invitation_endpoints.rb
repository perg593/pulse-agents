# frozen_string_literal: true

RSpec.shared_examples "invitation endpoints" do
  # A hash of valid parameters to send to the endpoint
  def valid_params
    raise NotImplementedError, "You must provide 'valid_params' to use 'invitation endpoints'"
  end

  # The active user, i.e. the one doing the inviting
  def acting_user
    raise NotImplementedError, "You must provide 'acting_user' to use 'invitation endpoints'"
  end

  # The account to invite new users to
  def account_for_invitation
    raise NotImplementedError, "You must provide 'account_for_invitation' to use 'invitation endpoints'"
  end

  def it_produces_a_valid_invitation
    expect(Invitation.count).to eq(1)
    expect(Invitation.first.account_id).to eq(account_for_invitation.id)
    expect(Invitation.first.email).to eq(valid_params[:invitation][:email])
    expect(Invitation.first.level).to eq(valid_params[:invitation][:level])
  end

  it "creates an invitation for a full access user" do
    sign_in @user

    level = User.levels["full"]
    valid_params[:invitation][:level] = level

    post :invite, params: valid_params

    it_produces_a_valid_invitation
  end

  it "creates an invitation for a reporting-only user" do
    sign_in @user

    level = User.levels["reporting"]
    valid_params[:invitation][:level] = level

    post :invite, params: valid_params

    it_produces_a_valid_invitation
  end

  it "is not available without signing in" do
    post :invite, params: valid_params

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to eq(sign_in_url)
  end

  it "does not create an invitation for an invalid e-mail address" do
    sign_in acting_user

    invalid_addresses = [nil, "", " ", "ekohe.com"]

    invalid_addresses.each do |invalid_address|
      valid_params[:invitation][:email] = invalid_address

      post :invite, params: valid_params

      expect(Invitation.count).to eq(0)
    end
  end

  it "does not create an invitation for an e-mail address belonging to an existing user" do
    sign_in acting_user
    existing_user = create(:user)

    valid_params[:invitation][:email] = existing_user.email

    post :invite, params: valid_params

    expect(Invitation.count).to eq(0)
  end

  it "sends an e-mail" do
    expect do
      sign_in acting_user
      post :invite, params: valid_params
    end.to change { ActionMailer::Base.deliveries.count }.by(1)
  end
end
