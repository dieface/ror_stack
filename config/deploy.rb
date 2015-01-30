require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'
require 'mina_sidekiq/tasks'
require 'mina/chruby'
# require 'mina/unicorn'


# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

set :domain, '54.92.4.177'
set :deploy_to, '/home/ubuntu/apps/MyApp'
set :repository, 'git@github.com:fockerlee/ror_stack.git'
set :branch, 'master'
set :user, 'ubuntu'
set :forward_agent, true
set :port, '22'
# set :unicorn_pid, "#{deploy_to}/shared/tmp/pids/unicorn.pid"

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, ['config/database.yml', 'log', 'config/secrets.yml']

# ### chruby_path
# Path where *chruby* init scripts are installed.
#
set :chruby_path, "/usr/local/share/chruby/chruby.sh"

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  queue %{
echo "-----> Loading environment"
#{echo_cmd %[source ~/.bashrc]}
}
  invoke :'chruby[ruby-2.1.3]'
  #invoke :'ruby:load'
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .rbenv-version to your repository.
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/shared/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/config"]

  queue! %[touch "#{deploy_to}/shared/config/database.yml"]
  queue  %[echo "-----> Be sure to edit 'shared/config/database.yml'."]

  queue! %[touch "#{deploy_to}/shared/config/secrets.yml"]
  queue %[echo "-----> Be sure to edit 'shared/config/secrets.yml'."]

  # sidekiq needs a place to store its pid file and log file
  queue! %[mkdir -p "#{deploy_to}/shared/pids/"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/pids"]

  queue! %[mkdir -p "#{deploy_to}/shared/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/log"]

  # puma needs a place to store its pid file and socket and log file.
  queue! %[mkdir -p "#{deploy_to}/shared/tmp/pids/"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/tmp/pids"]

  queue! %(mkdir -p "#{deploy_to}/#{shared_path}/tmp/sockets")
  queue! %(chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/tmp/sockets")

  queue! %[mkdir -p "#{deploy_to}/shared/tmp/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/tmp/log"]
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do

    # stop accepting new workers
    invoke :'sidekiq:quiet'

    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'

    to :launch do
      invoke :'sidekiq:restart'
      #invoke :'unicorn:restart'
      puma:phased_restart
    end
  end
end
