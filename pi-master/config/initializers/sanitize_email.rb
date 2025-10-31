SanitizeEmail::Config.configure do |config|
  config[:sanitized_to]    = 'alerts@pulseinsights.com'
  config[:activation_proc] = Proc.new { %w(development staging develop).include?(Rails.env) }
  config[:good_list]       = %w(jeremy@pulseinsights.com projas@pulseinsights.com bkirastoulis@pulseinsights.com dstahulak@pulseinsights.com jonathan@ekohe.com masakazu@ekohe.com staging.scan@rapid7.com)
  config[:use_actual_email_prepended_to_subject] = true
  config[:use_actual_environment_prepended_to_subject] = true
  config[:use_actual_email_as_sanitized_user_name] = true
end
