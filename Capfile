# -*- mode:ruby; -*-
#
#  Set deploy target host/filesystem and install user/group to use from cap command line as so:
#
#  cap deploy  -S target=ripple.fcla.edu:/opt/web-services/sies/xmlresolution -S who=daitss:daitss
#

require 'rubygems'
require 'railsless-deploy'
require 'bundler/capistrano'

set :keep_releases, 5   # default is 5

set :bundle_flags,      "--deployment"
set :bundle_without,    []

set :repository,        "http://github.com/daitss/xmlresolution.git"
set :scm,               "git"
set :branch,            "master"

set :use_sudo,          false
set :user,              "daitss"
set :group,             "daitss"

def usage(*messages)
  STDERR.puts "Usage: cap deploy -S target=<host:filesystem> -S who=<user:group>"
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

if (variables[:who] and variables[:who] =~ %r{.*:.*})
  _user, _group = variables[:who].split(':', 2)
  set :user,  _user
  set :group, _group
end


role :app, domain


after "deploy:update", "deploy:layout"

namespace :deploy do

  desc "Create the directory hierarchy, as necessary, on the target host"
  task :layout, :roles => :app do

    ['collections', 'schemas', 'bundle'].each do |dir|  # want to preserve existing data, so keep state files in the shared directory
      realname = File.join(shared_path, dir)
      run "mkdir -p #{realname}"
      #run "chmod -R ug+rwX #{realname}"
    end

    #run "find #{shared_path} #{release_path} -type d | xargs chmod 2775"
    #run "find #{shared_path} #{release_path}  | xargs chgrp #{group}"
  end


end

