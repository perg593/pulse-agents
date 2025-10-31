hostname = `hostname`.strip

config = YAML.load(File.read("/var/www/#{ENV['RAILS_ENV']}/pi/shared/config/database.yml"))[ENV['RAILS_ENV']]['influxdb']

influx_client = InfluxDB::Client.new(config['database'], username: config['username'], password: config['password'], hosts: config['hosts'], port: config['port'], use_ssl: config['use_ssl'], retry: config['retry'])

loop do
  stats      = Sidekiq::Stats.new
  queue      = Sidekiq::Queue.new hostname == 'c2.pulseinsights.com' ? 'console' : 'default'
  processes  = Sidekiq::ProcessSet.new.filter { |process| process['hostname'] == hostname } # Some servers share a queue with another server

  metric =
    {
      series: 'pi_sidekiq',
      tags: { hostname: hostname },
      values: {
        enqueued: stats.enqueued,
        latency: queue.latency.to_f,
        running: processes.sum { |process| process['busy'] }
      }
    }

  influx_client.write_points(metric)

  sleep(10) # Grafana's minimum polling interval. Sidekiq polls each 5 seconds
end
