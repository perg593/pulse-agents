role :console, %w{staging.pulseinsights.com}
role :serving, %w{staging.pulseinsights.com}

set :deploy_to, "/var/www/staging/pi"
set :rails_env, :staging
set :rvm_ruby_version, "ruby-3.3.4@pi_staging"
set :branch, "staging"

namespace :deploy do
  task :configure_app do
    on roles(:console) do
      within release_path do
        %w(database.yml scheduler.yml).each do |file_name|
          execute("ln -s #{release_path}/config/server/#{fetch(:rails_env)}/#{file_name} #{release_path}/config/#{file_name}")
        end
      end
    end
  end

  task :configure_scripts do
    on roles(:console) do
      within release_path do
        %w(env.sh console.sh rack_server.sh sidekiq_influxdb_exporter.rb).each do |file_name|
          execute("rm -f #{shared_path}/scripts/#{file_name}")
          execute("ln -s #{release_path}/config/server/#{fetch(:rails_env)}/scripts/#{file_name} #{shared_path}/scripts/#{file_name}")
        end
      end
    end
  end
end
