# -*- mode:ruby; -*-

# Run as cap --set-before domain="remote host"  deploy

load    'deploy' if respond_to?(:namespace)  # cap2?
require 'rubygems'
require 'railsless-deploy'

set :application,       "xmlresolution"
set :repository,        "http://github.com/daitss/xmlresolution.git"
set :use_sudo,          false
set :deploy_to,         "/opt/web-services/sites/#{application}"
set :scm,               "git"

set :user,              "xmlrez"    unless variables[:user]
set :group,             "daitss"    unless variables[:group]


# set domain and test proxy to use from cap command line, e.g.
#
#  cap --set-before domain=xmlresolution.ripple.fcla.edu  --set-before test_proxy=sake.fcla.edu:3128  deploy
#

# set :domain,      "xmlresolution.ripple.sacred.net"
# set :domain,      "xmlresolution.ripple.daitss.net"

def usage(messages)
  STDERR.puts "Usage: deploy cap -S domain=<target domain> -S test_proxy=<target proxy>"  
  STDERR.puts messages.join("\n")
  STDERR.puts "You may also set the remote user and group similarly (defaults to #{user} and #{group}, respectively)."
  STDERR.puts "If you set the user, you must be able to ssh to the domain as that user."
  exit
end

errors = []
if not variables[:domain]
  errors.push 'The domain was not set (e.g., domain=ripple.fcla.edu).'
end

if not variables[:test_proxy]
  errors.push 'The test_proxy was not set (e.g. test_proxy=sake.fcla.edu:3128).'
end

usage(errors) unless errors.empty?




role :app, domain
role :web, domain
role :db,  domain, :primary => true

# After we've successfully updated, we run these tasks: layout sets up
# the directory structure and runs bundle to install our own gem
# dependencies; docs builds library documentation into
# public/internals/; restart touches the file that instructs passenger
# phusion to restart the app; spec runs the spec tests.

after "deploy:update", "deploy:layout", "deploy:docs", "deploy:spec", "deploy:restart"

namespace :deploy do

  task :start do  # setup sudo command to restart apache?  Isn't necessary yet.
  end

  task :stop do
  end

  task :restart, :roles => :app, :except => { :no_release => true } do  # passenger phusion restarts when it detects this sentinel file  has changed mtime
    run "touch #{File.join(current_path, 'tmp', 'restart.txt')}"
  end

  task :layout, :roles => :app do

    ['data', 'public'].each do |dir|               # might not be in git, since these directories are usually empty.
      pathname = File.join(current_path, dir)
      run "mkdir -p #{pathname}"
      run "chmod -R ug+rwX #{pathname}"
    end

    ['vendor', 'collections', 'schemas'].each do |dir|    # want to preserve existing data, so let's keep these in the shared directory and link into them.
      realname = File.join(shared_path, dir)
      linkname = File.join(current_path, 'data')
      run "ln -s #{realname} #{linkname}"
      run "chmod -R ug+rwX #{realname}"
    end

    run "cd #{current_path}; bundle install #{File.join(shared_path, "vendor")}"   # extract gems if necessary

    # for production we'll want to keep our hands off, but it seems
    # reasonable, for now, to let anyone in the #{group} group tweak
    # the files on the server.

    run "find #{shared_path} #{release_path} -type d | xargs chmod 2775"
    run "find #{shared_path} #{release_path}  | xargs chgrp #{group}"
  end

  task :docs, :roles => :app do                     # generate fresh rdoc.
    run "cd #{current_path}; rake docs"
    run "chmod -R ug+rwX #{File.join(current_path, 'public', 'internals')}"
  end

  task :spec, :roles => :app do                     # run spec tests, ci
    run "cd #{current_path}; RESOLVER_PROXY=#{test_proxy} rake spec"
  end
end

