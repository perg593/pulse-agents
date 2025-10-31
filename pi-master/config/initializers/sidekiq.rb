class PostgresqlDisconnection
  def call(worker, job, queue)
    yield
  ensure
    worker.postgres_disconnect! if worker.respond_to? :postgres_disconnect!
  end
end

database_yml = YAML.load_file(File.expand_path("../../../config/database.yml",__FILE__), aliases: true)[Rails.env]

if database_yml.nil?
  puts "Error: No redis configuration for env #{Rails.env}"
else
  Sidekiq.failures_max_count = 5000

  Sidekiq.configure_server do |config|
    config.redis = { url: database_yml["redis"] }

    config.server_middleware do |chain|
      chain.add PostgresqlDisconnection
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: database_yml["redis"] }
  end
end

Sidekiq.strict_args!(:warn)

require 'sidekiq/scheduler'
Sidekiq.schedule = YAML.load_file(File.expand_path("../../../config/scheduler.yml",__FILE__)) || {}
