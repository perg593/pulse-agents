# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    return if Rails.env.test? # Inline surveys.js

    policy.default_src :self
    policy.script_src :self,
                      'survey.pulseinsights.com', 'staging-survey.pulseinsights.com', 'develop-survey.pulseinsights.com', # Rack app
                      'cdn.rollbar.com', 'agent.newrelic.com', 'www.googletagmanager.com', # Monitoring/Reporting
                      'cdnjs.cloudflare.com', # Editor(Jodit)
                      'phbxd.qrveyapp.com', 'd2nxqn82dnea4g.cloudfront.net' # Qrvey
    policy.connect_src :self,
                       'api.rollbar.com', 'bam.nr-data.net', 'rs.fullstory.com', 'edge.fullstory.com', 'www.google-analytics.com', # Monitoring/Reporting
                       'phbxd.qrveyapp.com', # Qrvey
                       'ws://localhost:3035', 'http://localhost:3035', # Webpack dev server
                       "828429778647phbxdqrveyuserfiles.s3.us-east-1.amazonaws.com", # Qrvey report exports
                       "ws://21qun8nj84.execute-api.us-east-1.amazonaws.com" # Qrvey Smart Analyzer
    policy.style_src :self, :https, :unsafe_inline # Webpack's injectStylesIntoStyleTag.js
    policy.img_src :self,
                   :data,
                   "https://cdn.pulseinsights.com",
                   "phbxd.qrveyapp.com" # Qrvey
    policy.font_src :self, :https
    policy.frame_src :self, :blob
    policy.worker_src :self, :blob
#     policy.object_src  :none
#     # Specify URI for violation reports
#     # policy.report_uri "/csp-violation-report-endpoint"
#     # policy.upgrade_insecure_requests # Treat any assets over HTTP as HTTPS (default: true)
  end
#
#   # Generate session nonces for permitted importmap and inline scripts
#   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
#   config.content_security_policy_nonce_directives = %w(script-src)
#
#   # Report violations without enforcing the policy.
#   # config.content_security_policy_report_only = true
end
