namespace 'deploy' do
  namespace 'assets' do
    task :cloudfront_invalidate_files do
      on roles(:console) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :rake, "cloudfront_invalidate_files[#{fetch(:stage)}]"
          end
        end
      end
    end
  end
end
