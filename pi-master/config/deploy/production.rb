role :console, %w{c2.pulseinsights.com}
role :reporting, %w{reporting.pulseinsights.com}
role :backup, %w{backup.pulseinsights.com}
role :serving, %w{s2.pulseinsights.com s4.pulseinsights.com s5.pulseinsights.com s6.pulseinsights.com s7.pulseinsights.com s8.pulseinsights.com}

set :deploy_to, "/var/www/production/pi"
set :rails_env, :production
set :rvm_ruby_version, "ruby-3.3.4@pi_production"
set :branch, "master"

namespace :deploy do
  desc 'Refresh config files'
  task :configure_app do
    %i(console reporting serving backup).each do |role|
      # Setting a minimal db pool size that matches the Sidekiq thread count to maximize
      # throughput while reducing the risk of exhausting the primary db's connection pool
      def db_config_filename(host)
        case host
        when /s5/
          'database_small.yml'
        when /s7/
          'database_large.yml'
        else
          'database.yml'
        end
      end

      on roles(role) do |host|
        within release_path do
          symlink_source_path = "#{release_path}/config/server/#{fetch(:rails_env)}/config/#{role}"
          execute("ln -s #{symlink_source_path}/#{db_config_filename(host.hostname)} #{release_path}/config/database.yml")
          execute("ln -s #{symlink_source_path}/scheduler.yml #{release_path}/config/scheduler.yml")
        end
      end
    end
  end

  task :configure_scripts do
    on roles(:console, :reporting, :serving) do
      within release_path do
        %w(env.sh console.sh sidekiq_influxdb_exporter.rb).each do |file_name|
          execute("rm -f #{shared_path}/scripts/#{file_name}")
          execute("ln -s #{release_path}/config/server/#{fetch(:rails_env)}/scripts/#{file_name} #{shared_path}/scripts/#{file_name}")
        end
      end
    end
    on roles(:serving) do
      within release_path do
        %w(rack_server.sh).each do |file_name|
          execute("rm -f #{shared_path}/scripts/#{file_name}")
          execute("ln -s #{release_path}/config/server/#{fetch(:rails_env)}/scripts/serving/#{file_name} #{shared_path}/scripts/#{file_name}")
        end
      end
    end
  end

  desc 'Create application tmp directory'
  task :create_app_tmp_directory do
    on roles(:serving) do
      within release_path do
        execute("mkdir #{release_path}/tmp")
      end
    end
  end
end

after 'deploy:updated', :create_app_tmp_directory

namespace :db do
  role :publisher, roles(:console)
  role :subscribers, roles(:serving) + roles(:reporting) + roles(:backup)

  # https://guides.rubyonrails.org/configuring.html#connection-preference
  set :subscriber_db_url, "postgresql://pi:HmXB%7DhFBx6Mjz6%5D%23%40dpY@127.0.0.1:5433/pi" 

  desc 'Execute migrations against subscribers'
  task :migrate_subscribers do
    on roles(:subscribers) do |host|
      within release_path do
        with(
          rails_env: fetch(:rails_env),
          DATABASE_URL: fetch(:subscriber_db_url),
          SCHEMA_MIGRATIONS_TABLE_NAME: 'subscriber_schema_migrations'
        ) do
          execute :rake, "db:migrate"
        end
      end
    end
  end
  
  desc 'Execute migrations against the publisher'
  task :migrate_publisher do
    on roles(:publisher) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:migrate"
        end
      end
    end
  end
  
  desc 'Refresh subscriptions'
  task :refresh_subscriptions do
    on roles(:subscribers) do |host|
      subscription_name = "pi_production_#{host.hostname.split('.').first}_subscription"
      execute %(psql "#{fetch(:subscriber_db_url)}" -c "ALTER SUBSCRIPTION #{subscription_name} REFRESH PUBLICATION;")
    end
  end
end

Rake::Task["deploy:migrating"].clear_actions

namespace :deploy do
  task :migrate do
    invoke 'db:migrate_subscribers'
    invoke 'db:migrate_publisher'
    invoke 'db:refresh_subscriptions'
  end
end
