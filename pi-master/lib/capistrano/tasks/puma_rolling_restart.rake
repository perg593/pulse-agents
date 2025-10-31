# frozen_string_literal: true

require_relative "../../../app/lib/retryable"

namespace :deploy do
  set :puma_backends, (lambda do
    [
      { service: "pi_#{fetch(:rails_env)}_puma_1", socket: "puma1.socket" },
      { service: "pi_#{fetch(:rails_env)}_puma_2", socket: "puma2.socket" }
    ]
  end)

  set :socket_directory, -> { "/var/www/#{fetch(:rails_env)}/pi/shared/sockets" }

  set :health_check_url, "http://localhost/heartbeat"

  task :puma_rolling_restart do
    on roles(:console) do
      fetch(:puma_backends).each do |puma_backend|
        execute :sudo, :monit, :restart, puma_backend.fetch(:service)

        socket_path = File.join(fetch(:socket_directory), puma_backend.fetch(:socket))

        Retryable.with_retry(max_retry_count: 60, interval: 1, logger: Logger.new(IO::NULL)) do
          execute :curl, "-fs", "--unix-socket", socket_path, fetch(:health_check_url)
        end
      end
    end
  end
end
