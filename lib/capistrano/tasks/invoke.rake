namespace :rake_task do
  desc "Run a task on a remote server."
  task :invoke do
    on roles(:app) do
      execute "cd #{deploy_to}/current; /usr/bin/env bundle exec rake #{ENV['task']} RACK_ENV=#{fetch(:stage)}"
    end
  end
end
