# frozen_string_literal: true
require 'spec_helper'

describe "Session" do
  let(:user) { create(:user) }
  let(:account) { user.account }

  # TODO: This isn't entirely appropriate for an integration test.
  # Consider testing whether they reached the desired page or some other outcome of
  # being signed in successfully
  def signed_in?
    request.env['warden'].authenticated?(:user)
  end

  context "when authentication fails" do
    let(:params) { { user: { email: user.email, password: FFaker::Lorem.word } } }

    before do
      ActionController::Base.allow_forgery_protection = true

      # We need to get the authenticity_token used by the signin form
      # to include in our POST request
      get '/sign_in'

      # Authenticity_token is the first input
      @authenticity_token = Nokogiri::HTML(response.body).css('input')[0].attributes["value"].value
    end

    after do
      ActionController::Base.allow_forgery_protection = false
    end

    it "redirects to the sign_in page" do
      post '/users/sign_in', params: params.merge(authenticity_token: @authenticity_token)

      expect(signed_in?).to be false
      assert_response 302
      assert_redirected_to sign_in_url
      # TODO: Find a better way to confirm that Sessions#new (the sign in page) is rendered
      # expect(response.body.include?("Sign In")).to be true
    end
  end

  context "when MFA is active for the user" do
    before do
      user.update(otp_secret: User.generate_otp_secret)
      @unencrypted_backup_codes = user.generate_otp_backup_codes!
      user.activate_mfa!
    end

    describe "adaptive MFA" do
      let(:ip_address) { "192.168.1.100" }
      let(:user_agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" }
      let(:first_signin_step_params) { { user: { email: user.email, password: user.password } } }
      let(:headers) { { 'HTTP_USER_AGENT' => user_agent, 'HTTP_X_FORWARDED_FOR' => ip_address } }

      context "when the user has no previous successful MFA signins" do
        it "requires MFA on signin" do
          post '/users/sign_in', params: first_signin_step_params, headers: headers
          follow_redirect!

          expect(signed_in?).to be false
          expect(response.body.include?("Sign In with MFA")).to be true
        end
      end

      context "when the user has a recent successful MFA signin from the same IP and user agent" do
        before do
          create(:successful_mfa_signin, user: user, ip_address: ip_address, user_agent: user_agent, created_at: 2.weeks.ago)
        end

        it "skips MFA and signs in the user directly" do
          post '/users/sign_in', params: first_signin_step_params, headers: headers

          expect(signed_in?).to be true
        end

        it "does not create a SuccessfulMFASignin record" do
          expect do
            post '/users/sign_in', params: first_signin_step_params, headers: headers
          end.not_to change(SuccessfulMFASignin, :count)
        end
      end

      context "when the user has an old successful MFA signin from the same IP and user agent" do
        before do
          create(:successful_mfa_signin,
                 user: user,
                 ip_address: ip_address,
                 user_agent: user_agent,
                 created_at: 2.months.ago)
        end

        it "requires MFA on signin" do
          post '/users/sign_in', params: first_signin_step_params, headers: headers
          follow_redirect!

          expect(signed_in?).to be false
          expect(response.body.include?("Sign In with MFA")).to be true
        end
      end

      context "when the user has a successful MFA signin from a different IP" do
        before do
          create(:successful_mfa_signin,
                 user: user,
                 ip_address: "10.0.0.1",
                 user_agent: user_agent,
                 created_at: 2.weeks.ago)
        end

        it "requires MFA on signin" do
          post '/users/sign_in', params: first_signin_step_params, headers: headers
          follow_redirect!

          expect(signed_in?).to be false
          expect(response.body.include?("Sign In with MFA")).to be true
        end
      end

      context "when the user has a successful MFA signin with a different user agent" do
        before do
          create(:successful_mfa_signin,
                 user: user,
                 ip_address: ip_address,
                 user_agent: "Different Browser",
                 created_at: 2.weeks.ago)
        end

        it "requires MFA on signin" do
          post '/users/sign_in', params: first_signin_step_params, headers: headers
          follow_redirect!

          expect(signed_in?).to be false
          expect(response.body.include?("Sign In with MFA")).to be true
        end
      end

      context "when the user successfully completes MFA" do
        before do
          post '/users/sign_in', params: first_signin_step_params, headers: headers
          follow_redirect!
          patch complete_mfa_path, params: { user: { otp_attempt: user.current_otp } }, headers: headers
        end

        it "creates a SuccessfulMFASignin record" do
          expect(SuccessfulMFASignin.count).to eq(1)
          successful_mfa_signin = SuccessfulMFASignin.first

          expect(successful_mfa_signin.user).to eq(user)
          expect(successful_mfa_signin.ip_address).to eq(IPAddr.new(ip_address))
          expect(successful_mfa_signin.user_agent).to eq(user_agent)
        end

        it "allows subsequent signins from the same IP and user agent without MFA" do
          # Sign out first
          delete '/logout'

          # Try to sign in again
          post '/users/sign_in', params: first_signin_step_params, headers: headers

          expect(signed_in?).to be true
        end
      end
    end

    context "when the correct e-mail and an incorrect password are provided" do
      let(:first_signin_step_params) { { user: { email: user.email, password: "WRONG" } } }

      before do
        post '/users/sign_in', params: first_signin_step_params
        follow_redirect!
      end

      it "does not sign them in" do
        expect(signed_in?).to be false
      end

      it "reloads the signin page" do
        expect(response.body.include?("Sign in")).to be true
      end
    end

    context "when an e-mail matching no user is provided" do
      let(:first_signin_step_params) { { user: { email: FFaker::Internet.email, password: user.password } } }

      before do
        post '/users/sign_in', params: first_signin_step_params
        follow_redirect!
      end

      it "does not sign them in" do
        expect(signed_in?).to be false
      end

      it "reloads the signin page" do
        expect(response.body.include?("Sign in")).to be true
      end
    end

    context "when the correct e-mail and password are provided" do
      let(:first_signin_step_params) { { user: { email: user.email, password: user.password } } }

      before do
        post '/users/sign_in', params: first_signin_step_params
        follow_redirect!
      end

      it "does not sign them in" do
        expect(signed_in?).to be false
      end

      it "directs them to the MFA signin page" do
        expect(response.body.include?("Sign In with MFA")).to be true
      end

      context "when the user provides a valid backup code" do
        before do
          patch complete_mfa_path, params: { user: { otp_attempt: @unencrypted_backup_codes.first } }
        end

        it "signs in the user" do
          expect(signed_in?).to be true
        end
      end

      context "when the user provides a valid one time password" do
        before do
          patch complete_mfa_path, params: { user: { otp_attempt: user.current_otp } }
        end

        it "signs in the user" do
          expect(signed_in?).to be true
        end

        it "creates a SigninActivity record" do
          expect(SigninActivity.count).to eq(1)
        end
      end

      context "when the user provides an invalid backup code" do
        before do
          patch complete_mfa_path, params: { user: { otp_attempt: "fake" } }
          follow_redirect!
        end

        it "does not sign in the user" do
          expect(signed_in?).to be false
        end

        it "reloads the signin page" do
          expect(response.body.include?("Sign in")).to be true
        end
      end

      context "when the user provides an invalid backup code 8 times" do
        let(:first_signin_step_params) { { user: { email: user.email, password: user.password } } }

        before do
          8.times do
            post '/users/sign_in', params: first_signin_step_params, headers: headers
            patch complete_mfa_path, params: { user: { otp_attempt: "fake" } }
          end
        end

        it "locks the user" do
          user.reload
          # TODO: Find a workaround to "double-counting" bug in library
          # https://github.com/devise-two-factor/devise-two-factor/issues/127
          expect(user.failed_attempts).to eq(16)
          expect(user.access_locked?).to be true
        end
      end
    end
  end

  context "when MFA is not active for the account" do
    context "when the correct e-mail and password are provided" do
      let(:params) { { user: { email: user.email, password: user.password } } }

      it "signs in the user" do
        post '/users/sign_in', params: params

        expect(signed_in?).to be true
      end

      it "creates a SigninActivity record" do
        post '/users/sign_in', params: params

        expect(signed_in?).to be true
        expect(SigninActivity.count).to eq(1)
      end

      context "when the request is not POST" do
        it "fails to sign in the user" do
          get '/sign_in', params: params

          expect(signed_in?).to be false
        end
      end

      context "when the user is inactive" do
        it "fails to sign in the user" do
          user.update(active: false)

          post '/users/sign_in', params: params

          expect(signed_in?).to be false

          # TODO: Decide how much to reveal to users
          # error_message = Nokogiri::HTML(response.body).css(".error").last.text
          # expect(error_message).to include("This account is deactivated")
        end
      end

      context "when the user is locked" do
        it "fails to sign in the user" do
          user.lock_access!
          ActionMailer::Base.deliveries.clear

          post '/users/sign_in', params: params

          expect(signed_in?).to be false
        end
      end
    end

    context "when the e-mail address is in a different case" do
      let(:params) { { user: { email: user.email.upcase, password: user.password } } }

      it "signs in the user" do
        post '/users/sign_in', params: params

        expect(signed_in?).to be true
      end
    end

    context "when the user parameter is missing" do
      let(:params) { {} }

      it "fails to sign in the user" do
        post '/users/sign_in', params: params

        expect(signed_in?).to be false
      end
    end

    context "when the e-mail is missing" do
      let(:params) { { user: { password: user.password } } }

      it "fails to sign in the user" do
        post '/users/sign_in', params: params

        expect(signed_in?).to be false
      end
    end

    context "when the password is missing" do
      let(:params) { { user: { email: user.email } } }

      it "fails to sign in the user" do
        post '/users/sign_in', params: params

        expect(signed_in?).to be false
      end
    end

    context "when the password is incorrect" do
      let(:params) { { user: { email: user.email, password: FFaker::Lorem.word } } }

      before do
        post '/users/sign_in', params: params
      end

      it "fails to sign in the user" do
        expect(signed_in?).to be false
      end

      it "redirects to the signin page" do
        assert_redirected_to sign_in_url
      end

      it "increments the user's failed_attempts count" do
        user.reload
        # TODO: Find a workaround to "double-counting" bug in library
        # https://github.com/devise-two-factor/devise-two-factor/issues/127
        expect(user.failed_attempts).to eq(2)
      end

      it "does not create a SigninActivity record" do
        expect(SigninActivity.count).to eq(0)
      end
    end

    context "when the password is incorrect 8 times in a row" do
      let(:params) { { user: { email: user.email, password: FFaker::Lorem.word } } }

      before do
        8.times do
          post '/users/sign_in', params: params
        end
      end

      it "locks the user" do
        user.reload
        # TODO: Find a workaround to "double-counting" bug in library
        # https://github.com/devise-two-factor/devise-two-factor/issues/127
        expect(user.failed_attempts).to eq(16)
        expect(user.access_locked?).to be true
      end

      it "sends an e-mail to the user" do
        expect(UserMailer.deliveries.count).to eq 2

        notification_email = UserMailer.deliveries.find { |email| email.to == [user.email] }

        expect(notification_email.subject).to eq "Unlock instructions"
        expect(notification_email.to).to eq([user.email])
        expect(notification_email.cc).to be_nil
        expect(notification_email.bcc).to eq(["ops@pulseinsights.com"])

        expect(notification_email.body).to include("Your account has been locked")
      end

      it "sends an e-mail to admins" do
        expect(UserMailer.deliveries.count).to eq 2

        notification_email = UserMailer.deliveries.find { |email| email.to == ["alerts@pulseinsights.com"] }

        expect(notification_email.subject).to eq "[Pulse Insights] 8 unsuccessful login attempts for #{user.email}"
        expect(notification_email.to).to eq(["alerts@pulseinsights.com"])
        expect(notification_email.cc).to be_nil
        expect(notification_email.bcc).to eq(["ops@pulseinsights.com"])

        expect(notification_email.body).to include("#{user.email} has been locked")
      end
    end

    context "when the e-mail address is incorrect" do
      let(:params) { { user: { email: FFaker::Internet.email, password: user.password } } }

      it "fails to sign in the user" do
        post '/users/sign_in', params: params

        expect(signed_in?).to be false
      end
    end
  end
end
