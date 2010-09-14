# -*- mode:ruby; -*-
#
#  Set domain and test proxy to use from cap command line as so:
#
#  cap deploy  -S domain=xmlresolution.ripple.fcla.edu  -S test_proxy=sake.fcla.edu:3128
#
#  The test-proxy is used only in remote spec tests.
#  One can over-ride user and group settings the same way.

load    'deploy'
require 'rubygems'
require 'railsless-deploy'
require 'bundler/capistrano'


set :application,       "xmlresolution"
set :repository,        "http://github.com/daitss/xmlresolution.git"
set :use_sudo,          false
set :deploy_to,         "/opt/web-services/sites/#{application}"
set :scm,               "git"
set :branch,            "master"
set :user,              "xmlrez"    unless variables[:user]
set :group,             "daitss"    unless variables[:group]

# set :git_shallow_clone,  1  # doesn't work for some reason...maybe I'm not waiting long enough.
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

# After we've successfully updated, we run these tasks: layout sets up
# the directory structure and runs bundle to install our own gem
# dependencies; docs builds library documentation into
# public/internals/; restart touches the file that instructs passenger
# phusion to restart the app; spec runs the spec tests.

after "deploy:update", "deploy:layout", "deploy:docs", "deploy:spec", "deploy:restart"

namespace :deploy do

  desc "Touch the tmp/restart.txt file on the target host, which signals passenger phusion to reload the app"
  task :restart, :roles => :app, :except => { :no_release => true } do  # passenger phusion restarts when it detects this sentinel file  has changed mtime
    run "touch #{File.join(current_path, 'tmp', 'restart.txt')}"
  end

  desc "Create the directory hierarchy, as necessary, on the target host"
  task :layout, :roles => :app do

    ['data', 'public'].each do |dir|                    # might not be in git since these directories are usually empty - create if necessary
      pathname = File.join(current_path, dir)
      run "mkdir -p #{pathname}"
      run "chmod -R ug+rwX #{pathname}"
    end

    ['vendor', 'collections', 'schemas'].each do |dir|  # want to preserve existing data, so keep in the shared directory and link into them.
      realname = File.join(shared_path, dir)
      linkname = File.join(current_path, 'data')
      run "mkdir -p #{realname}"
      run "ln -s #{realname} #{linkname}"
      run "chmod -R ug+rwX #{realname}"
    end

    run "cd #{current_path}; bundle install #{File.join(shared_path, "vendor")}"   # extract gems if necessary

    # For production we'll want to keep our hands off, but it seems
    # reasonable, for now, to let anyone in the #{group} group tweak
    # the files on the server.

    run "find #{shared_path} #{release_path} -type d | xargs chmod 2775"
    run "find #{shared_path} #{release_path}  | xargs chgrp #{group}"
  end

  desc "Create documentation in public/internals via a rake task - tries yard, hanna, and rdoc"
  task :docs, :roles => :app do                     # generate fresh rdoc.
    run "cd #{current_path}; rake docs"
    run "chmod -R ug+rwX #{File.join(current_path, 'public', 'internals')}"
  end

  desc "Run spec tests on the target host via rake - will use ci/reporter if available"
  task :spec, :roles => :app do                     # run spec tests, ci
    run "cd #{current_path}; RESOLVER_PROXY=#{test_proxy} rake spec"
  end
end

