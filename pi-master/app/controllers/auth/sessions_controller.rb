# frozen_string_literal: true
module Auth
  class SessionsController < BaseController
    skip_before_action :require_logout!, only: :destroy
    before_action :require_user!, only: :destroy

    skip_before_action :verify_authenticity_token, only: :omniauth
    before_action :require_omniauth_object, only: :omniauth

    prepend_before_action :check_mfa_required, only: [:create]

    # Necessary for devise to allow our parameters to authenticate the user.
    # Without this, the user's warden strategies will be considered invalid,
    # Ideally our controller would be subclassing Devise::SessionsController rather
    # than copy+pasting functionality like this.
    prepend_before_action :allow_params_authentication!, only: [:complete_mfa, :create]

    def new
      @user = User.new(sign_in_params)

      if warden && warden.message.present?
        if params[:action] == "omniauth"
          flash.now.alert = warden.message
        else
          @user.errors.add(:password, warden.message)
        end
      end

      # Google favicon request
      head(404) && return if request.headers['HTTP_ACCEPT'] == "image/*"
    end

    def initiate_saml
      user = User.find_by_unfolded_email(params[:email])

      if user&.account&.idp_set_up?
        idp_config = user.account.idp_config('comcast')

        redirect_to url_for(Saml.create_saml_auth_request(idp_config))
      else
        redirect_to sign_in_url
      end
    end

    def omniauth
      case request.env['omniauth.auth'].provider
      when "google_oauth2"
        warden.authenticate!(:oauth)
      when "saml"
        warden.authenticate!(:saml)
      else
        Rails.logger.info "provider not recognized: #{request.env['omniauth.auth'].provider}"
        redirect_to sign_in_url and return
      end

      session[:from_login] = 'yes'

      redirect_to after_sign_in_url
    rescue ActiveRecord::RecordNotFound
      redirect_to sign_in_url
    end

    # Ideally this would use Devise's built-in endpoint
    # We're probably missing out on some authentication logic here
    def create
      warden.authenticate!(scope: :user)
      redirect_to after_sign_in_url

      session[:from_login] = 'yes'
    rescue ActiveRecord::RecordNotFound
      redirect_to sign_in_url
    end

    def destroy
      session.delete(:sudo_from_id)
      warden.logout
      redirect_to after_logout_url, notice: "Logged out!"
    end

    def mfa_signin
      # The existence of session[:email] implies that they made it through signin
      # We could maybe be more explicit about their semi-authenticated state
      @user = User.find_by(email: session[:email])

      redirect_to sign_in_url unless @user
    end

    def complete_mfa
      email = session[:email]
      password = session[:password]

      request.params[:user].merge!(
        email: email,
        password: password
      )

      warden.authenticate!

      SuccessfulMFASignin.create!(user: current_user, ip_address: request.remote_ip, user_agent: request.user_agent)

      redirect_to after_sign_in_url

      session[:from_login] = 'yes'
    end

    private

    def check_mfa_required
      return unless params[:user].present?
      user = User.find_by(email: params[:user][:email])

      return unless user&.otp_required_for_login?
      # This validates the user's password, so we can safely log them in
      # if MFA is disabled or being skipped.
      return unless user.valid_password?(params[:user][:password])

      if SuccessfulMFASignin.recent.matching_fingerprint(request.remote_ip, request.user_agent).where(user_id: user.id).exists?
        # We can't let warden authenticate as usual because
        # the OTP checks will fail.
        warden.set_user(user)

        return
      end

      session[:email] = params[:user][:email]
      session[:password] = params[:user][:password]

      redirect_to mfa_signin_path
    end

    def sign_in_params
      params.fetch('user', {}).permit('email', 'password').transform_keys(&:to_sym)
    end

    # https://github.com/omniauth/omniauth-saml#usage
    def require_omniauth_object
      return if request.env['omniauth.auth']
      Rollbar.error 'OmniAuth Response Not Found', message: request.env['omniauth.error'], raw_info: request.env['omniauth.extra.raw_info']
      Rails.logger.error "OmniAuth Response Not Found - Message: #{request.env['omniauth.error']}, Raw Info: #{request.env['omniauth.extra.raw_info']}"
      redirect_to sign_in_url
    end
  end
end
