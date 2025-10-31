include CredentialLoader

set :application, "pi"

set :default_env, {
  COFFEESCRIPT_SOURCE_PATH: "vendor/assets/javascripts/coffeescript.js"
}

set :repo_url,  "git@gitlab.ekohe.com:ekohe/pulseinsights/pi.git"

set :use_sudo, false

set :rvm_type, :system

set :ssh_options, { user: (ENV['CAPISTRANO_USER'] || `whoami`.chop) }
set :user, ENV['CAPISTRANO_USER'] || `whoami`.chop

set :linked_files, %W{config/credentials/#{fetch(:stage)}.key}
set :linked_dirs, fetch(:linked_dirs, []).push(
  'log',
  'public/uploads'
)

set :tmp_dir, "/home/#{fetch(:user)}/tmp"

set :shared_path, "/var/www/#{fetch(:rails_env)}/#{fetch(:application)}/shared"

set :migration_role, :console
set :assets_roles, %i(console reporting)

if fetch(:stage) == :production
  set :rollbar_token, read_credentials(environment: fetch(:stage))["rollbar"]["token"]
  set :rollbar_env, Proc.new { fetch(:stage) }
  set :rollbar_role, Proc.new { :all }
end

Dir['config/deploy/extras/*.rb'].each { |file| load file }

task :link_non_digest_surveys_js do
  on roles(:console, :reporting, :serving) do
    # Create link to non-digest surveys.js
    within release_path do
      execute "ln -sf `ls -t #{release_path}/public/assets/surveys-*.js | head -n 1` #{release_path}/public/assets/surveys.js"
      execute "ln -sf `ls -t #{release_path}/public/assets/surveys-*.js.gz | head -n 1` #{release_path}/public/assets/surveys.js.gz"
      execute "ln -sf `ls -t #{release_path}/public/assets/surveys_no_callback-*.js | head -n 1` #{release_path}/public/assets/surveys_ncb.js"
      execute "ln -sf `ls -t #{release_path}/public/assets/surveys_no_callback-*.js.gz | head -n 1` #{release_path}/public/assets/surveys_ncb.js.gz"
    end
  end
end

before 'deploy:symlink:shared', 'deploy:configure_scripts'
before 'deploy:symlink:shared', 'deploy:configure_app'

namespace :deploy do
  desc 'Restart application'
  task :restart do
    invoke 'deploy:puma_rolling_restart'
    invoke 'deploy:monit_at_once_restart'
    invoke 'deploy:monit_rolling_restart'
  end
 
  task :monit_at_once_restart do
    on roles(:console, :reporting, :serving) do
      execute "sudo monit restart -g pi_#{fetch(:rails_env)}_at_once_restart"
    end
  end

  task :monit_rolling_restart do
    on roles(:reporting, :serving) do
      execute "sudo monit restart -g pi_#{fetch(:rails_env)}_rolling_restart_odd"
      sleep 30 # Each service requires a different method for status polling and the duration would also be different https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2310#note_1040090
      execute "sudo monit restart -g pi_#{fetch(:rails_env)}_rolling_restart_even"
    end
  end

  before 'assets:precompile', 'deploy:clobber_assets'
  before 'assets:precompile', 'deploy:yarn_install'

  # webpacker requires yarn
  task :yarn_install do
    on roles(:console, :reporting, :serving) do
      within release_path do
        execute("cd #{release_path} && yarn install --immutable")
      end
    end
  end

  after 'assets:precompile', :link_non_digest_surveys_js

  if %i(production staging develop).include? fetch(:stage)
    after 'assets:precompile', 'deploy:assets:upload_survey_js'
    after 'assets:precompile', 'deploy:assets:cloudfront_invalidate_files'
  end

  after :publishing, :restart

  Rake::Task["deploy:cleanup"].clear_actions
  desc "Clean up old releases"
  task :cleanup do
    on release_roles :all do |host|
      releases = capture(:ls, "-x", releases_path).split
      valid, invalid = releases.partition { |e| /^\d{14}$/ =~ e }

      warn t(:skip_cleanup, host: host.to_s) if invalid.any?

      if valid.count >= fetch(:keep_releases)
        info t(:keeping_releases, host: host.to_s, keep_releases: fetch(:keep_releases), releases: valid.count)
        directories = (valid - valid.last(fetch(:keep_releases)))
        if directories.any?
          directories_str = directories.map do |release|
            releases_path.join(release)
          end.join(" ")
          execute "sudo -u www-data bash -c 'rm -rf #{directories_str}'"
        else
          info t(:no_old_releases, host: host.to_s, keep_releases: fetch(:keep_releases))
        end
      end
    end
  end
end

set :notify_emails, ["deployment@pulseinsights.com"]

after 'deploy', 'deploy:notify'
