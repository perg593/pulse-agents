# https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2545
#   Adding a timestamp to logs to see when the process starts listening for requests.
#   That, combined with Monit logs, allows us to determine a sensible interval between process restarts during deployment.
log_formatter do |log|
  "#{Time.now}: #{log}" # Time.current is not available because ActiveSupport is not available
end
