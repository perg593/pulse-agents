config = YAML.load(File.read("/var/www/#{ENV['RAILS_ENV']}/pi/shared/config/database.yml"))[ENV['RAILS_ENV']]['influxdb']

influx_client = InfluxDB::Client.new(config['database'], username: config['username'], password: config['password'], hosts: config['hosts'], port: config['port'], use_ssl: config['use_ssl'], retry: config['retry'])

# Sidekiq's polling interval is 5 secs
loop do
  queue = Sidekiq::Queue.new('default')
  stats = Sidekiq::Stats.new

  metric =
    {
      series: 'pi_sidekiq',
      tags: { hostname: `hostname`.strip },
      values: { enqueued: stats.enqueued, latency: queue.latency }
    }

  influx_client.write_points(metric)

  sleep(10)
end
