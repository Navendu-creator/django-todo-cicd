# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'adobe-extension-api'
set :repo_url, 'git@github.com:fontshop/Adobe-Plugin-API.git'
set :linked_files, %w{config/database.yml config/app.yml config/.env}

set :user, "passenger"
set :deploy_to, "/home/passenger/adobe-extension-api"
set :deploy_via, :remote_cache

set :ssh_options, { :forward_agent => true }
set :use_sudo, false
set :passenger_restart_with_sudo, true

namespace :deploy do

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end



end
