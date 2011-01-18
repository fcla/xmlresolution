# -*- mode:ruby; -*-
#
#  Set deploy target host/filesystem and test proxy to use from cap command line as so:
#
#  cap deploy  -S target=ripple.fcla.edu:/opt/web-services/sies/xmlresolution  -S test_proxy=sake.fcla.edu:3128
#
#  The test-proxy is used only in remote spec tests.
#  One can over-ride user and group settings using -S who=user:group

require 'rubygems'
require 'railsless-deploy'

# require 'bundler/capistrano'   - can't get nokogiri to be compiled nor used from the system gems. more work to do.

set :bundle_flags,       "--deployment"
set :bundle_without,      []

set :repository,        "http://github.com/daitss/xmlresolution.git"
set :scm,               "git"
set :branch,            "master"

set :use_sudo,          false
set :user,              "xmlrez" #     unless variables[:user] - deprecated, see below
set :group,             "daitss"

def usage(*messages)
  STDERR.puts "Usage: cap deploy -S target=<host:filesystem> -S test_proxy=sake.fcla.edu:3128"  
  STDERR.puts messages.join("\n")
  STDERR.puts "You may set the remote user and group by using -S who=<user:group>. Defaults to #{user}:#{group}."
  STDERR.puts "If you set the user, you must be able to ssh to the target host as that user."
  STDERR.puts "You may set the branch in a similar manner: -S branch=<branch name> (defaults to #{variables[:branch]})."
  exit
end

usage('The deployment target was not set (e.g., target=ripple.fcla.edu:/opt/web-services/sites/silos).') unless (variables[:target] and variables[:target] =~ %r{.*:.*})

_domain, _filesystem = variables[:target].split(':', 2)

set :deploy_to,  _filesystem
set :domain,     _domain

usage 'The test_proxy was not set (e.g. test_proxy=sake.fcla.edu:3128).' unless variables[:test_proxy]

role :app, domain

# After we've successfully updated, we run these tasks: layout sets up
# the directory structure and runs bundle to install our own gem
# dependencies; docs builds library documentation into
# public/internals/; restart touches the file that instructs passenger
# phusion to restart the app; spec runs the spec tests.

# after "deploy:update", "deploy:layout", "deploy:spec", "deploy:restart"

after "deploy:update", "deploy:layout", "deploy:restart"

namespace :deploy do

  desc "Touch the tmp/restart.txt file on the target host, which signals passenger phusion to reload the app"
  task :restart, :roles => :app, :except => { :no_release => true } do  # passenger phusion restarts when it detects this sentinel file  has changed mtime
    run "touch #{File.join(current_path, 'tmp', 'restart.txt')}"
  end
  
  desc "Create the directory hierarchy, as necessary, on the target host"
  task :layout, :roles => :app do

    ['collections', 'schemas', 'vendor/bundle'].each do |dir|  # want to preserve existing data, so keep state files in the shared directory
      realname = File.join(shared_path, dir)
      run "mkdir -p #{realname}"
      run "chmod -R ug+rwX #{realname}"
    end

    run "find #{shared_path} #{release_path} -type d | xargs chmod 2775"
    run "find #{shared_path} #{release_path}  | xargs chgrp #{group}"
  end

  # deprecated for now in the above 'after' clause:

  desc "Run spec tests on the target host via rake - will use ci/reporter if available"
  task :spec, :roles => :app do
    run "cd #{current_path}; RESOLVER_PROXY=#{test_proxy} rake spec"
  end

end

