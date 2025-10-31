namespace 'deploy' do
  namespace 'assets' do
    task :upload_survey_js do
      on roles(:console) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :rake, "upload_survey_js[#{fetch(:stage)}]"
          end
        end
      end
    end
  end
end
