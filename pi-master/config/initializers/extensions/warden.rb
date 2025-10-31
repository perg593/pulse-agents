# Warden configurations
# Serialize the digital fingerprints of passwords into sessions so that all
# the associated sessions will be invalidated after a user change their password.
Warden::Manager.serialize_into_session do |user|
  user.encrypted_password # This isn't exposed to public
end
Warden::Manager.serialize_from_session do |encrypted_password|
  User.find_by_encrypted_password(encrypted_password)
end

Warden::Manager.after_authentication do |user,_auth,_opts|
  user.update_signin_info
  SigninActivity.create(account: user.account, user: user)
end

Warden::Manager.before_failure do |env, opts|
  env['warden.options'][:ip_address] = env['REMOTE_ADDR']
end

# The ActionCable server runs as a separate process and can access only cookies
Warden::Manager.after_set_user do |user, auth, opts|
  auth.cookies.signed["#{opts[:scope]}.id"] = user.id
end
Warden::Manager.before_logout do |_user, auth, opts|
  auth.cookies.signed["#{opts[:scope]}.id"] = nil
end

Warden::Strategies.add(:oauth) do
  def valid?
    return false unless request.env['omniauth.auth'].present?

    supported_providers = %w(google_oauth2)

    supported_providers.include?(request.env['omniauth.auth'].provider) && request.env.dig('omniauth.auth', 'info', 'email').present?
  end

  def authenticate!
    if user = User.find_by_unfolded_email(request.env['omniauth.auth']['info']['email'])
      if user.access_locked?
        fail! "You have been locked out for too many failed password attempts."
      elsif !user.active?
        fail! "This account is deactivated. Please contact support to reactivate it."
      else
        success!(user)
      end
    else
      fail! "We did not find a Pulse Insights account associated with this email. Please contact support@pulseinsights.com"
    end
  end
end

Warden::Strategies.add(:saml) do
  def valid?
    return false unless request.env['omniauth.auth'].present?

    supported_providers = %w(saml)

    supported_providers.include?(request.env['omniauth.auth'].provider) && request.env.dig('omniauth.auth', 'uid').present?
  end

  def authenticate!
    if user = User.find_by_unfolded_email(request.env['omniauth.auth']['info']['email'])
      if user.access_locked?
        fail! "You have been locked out for too many failed password attempts."
      elsif !user.active?
        fail! "This account is deactivated. Please contact support to reactivate it."
      else
        success!(user)
      end
    else
      fail! "We did not find a Pulse Insights account associated with this email. Please contact support@pulseinsights.com"
    end
  end
end
