# Bots trigger many ActionController::RoutingError errors, mostly by requesting
# files we don't serve. This is a list of common files they target.
# The goal is to prevent our Rollbar quota from being used up by bots.
file_blacklist = %w(
  wlwmanifest.xml
  wp-content
  wp-login.php
)

ip_whitelist = []
ip_whitelist.push *%w(34.192.183.106 34.205.208.125 34.227.121.223) # Rapid7
ip_whitelist.push *%w(34.82.99.36 34.95.145.221 34.105.164.255 34.107.83.48 34.124.205.48 34.131.190.84 35.189.46.39 35.198.150.95 35.200.159.241 35.221.55.248 35.245.116.24) # Pen testers
ip_whitelist.push '52.19.40.38' # Cobalt

# IP address known to spam invalid routes
ip_blacklist = %w(
  5.183.209.217 13.38.97.208 23.129.64.213 23.236.146.166 34.204.129.75 43.129.24.224 45.33.65.249 45.33.101.246 45.134.144.140 45.146.165.37
  45.129.56.200 45.154.255.147 47.243.233.244 47.253.205.215 51.15.67.157 78.128.113.170 107.172.75.164 104.199.55.175 104.208.30.108 114.132.41.72 116.204.211.140
  116.204.211.164 116.204.211.188 129.146.200.94 141.95.91.126 146.70.92.30 171.25.193.25 171.25.193.77 171.25.193.78 173.249.19.100 185.220.100.242 185.220.100.244
  185.220.101.52 185.56.80.65 185.191.127.212 185.220.100.245 185.220.100.249 185.220.100.252 185.220.100.253 192.241.224.82 193.106.191.48 208.109.36.200 209.141.58.146
  45.56.101.192 172.105.129.153 18.168.180.196 18.194.95.96 198.178.12.68 206.0.57.236 165.22.2.226 143.244.172.148 137.184.63.65
)

path_whitelist = [
  /^\/(assets|packs)\/.+/, # asset fetching requests to "/assets" and "/packs"
  /^\/report_jobs\/\d+\/status$/, # requests to "/report_jobs/:id/status"
  /^\/tag_automation_jobs\/\d+\/poll$/ # This endpoint polls ChatGPT tagging answers
]

Rack::Attack.safelist('allow whitelisted ips') do |request|
  ip_whitelist.include?(request.ip)
end

Rack::Attack.blocklist("block bots testing our defences") do |request|
  ip_blacklist.include?(request.ip) || file_blacklist.any? {|filename| request.path.include?(filename)}
end

Rack::Attack.blocklist("block ip addresses requesting any path too frequently") do |request|
  from_mobile_app = Rack::Utils.parse_nested_query(request.env["QUERY_STRING"])["device_type"] == "native_mobile"
  max_attempts = from_mobile_app ? 500 : 100

  Rack::Attack::Allow2Ban.filter(request.ip, maxretry: max_attempts, findtime: 180, bantime: 3600) do
    path_whitelist.none? { |path_pattern| path_pattern.match?(request.path) }
  end
end

# "/report_jobs/:id/status" is a polling endpoint that gets accessed 20rpm without user's effort
Rack::Attack.throttle("limit report job status requests per ip", limit: 20, period: 60) do |request|
  request.ip if request.get? && /^\/report_jobs\/\d+\/status$/.match?(request.path)
end

# "/survey_brief_jobs/:id" is a polling endpoint that gets accessed once per second
Rack::Attack.throttle("limit survey brief job requests per ip", limit: 70, period: 60) do |request|
  request.ip if request.get? && /^\/survey_brief_jobs\/\d+$/.match?(request.path)
end

# "/surveys/:id/ai_outline_jobs/:job_id" is a polling endpoint accessed every 5 seconds for job status
Rack::Attack.throttle("limit ai outline job status requests per ip", limit: 20, period: 60) do |request|
  request.ip if request.get? && /^\/surveys\/\d+\/ai_outline_jobs\/\d+$/.match?(request.path)
end

# "/surveys/:id/ai_outline_jobs/check_gamma_presentation_status" is a polling endpoint accessed every 5 seconds for Gamma status
Rack::Attack.throttle("limit ai outline job gamma status requests per ip", limit: 20, period: 60) do |request|
  request.ip if request.get? && /^\/surveys\/\d+\/ai_outline_jobs\/check_gamma_presentation_status$/.match?(request.path)
end
