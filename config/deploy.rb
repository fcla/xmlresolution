 set :application,       "xmlresolution"
 set :domain,            "xmlresolution.dev.fcla.edu"
 set :repository,        "ssh://retsina.fcla.edu//var/git/#{application}.git"
 set :local_repository,  "file:///var/git/#{application}.git"
 set :use_sudo,          false
 set :deploy_to,         "/opt/web-services/#{application}"
 set :scm,               "git"
#set :gateway,		 "gnvssh.fcla.edu:2020"   # what *is* my password?
#set :gateway,		 "fcla"                   # a host/port alias from .ssh/config

 role :app, domain
 role :web, domain
 role :db,  domain, :primary => true

after "deploy:update", "deploy:layout", "deploy:rdoc", "deploy:echo_revision", "deploy:restart"

 namespace :deploy do
    task :start do
    end

    task :stop do
    end

    task :restart, :roles => :app, :except => { :no_release => true } do
      run "touch #{File.join(current_path, 'tmp', 'restart.txt')}"
    end

    task :layout, :roles => :app do

      [ File.join(current_path, 'data', 'collections'),
 	File.join(current_path, 'data', 'schemas'), 
      	File.join(current_path, 'public') ].each  { |dir| run "mkdir -p #{dir}" }

      [ File.join(current_path, 'data'),
      	File.join(current_path, 'public') ].each  { |dir| run "chmod -R g+rwX #{dir}" }

    end

    task :rdoc, :roles => :app do
       run "cd #{current_path}; rake rdoc"
       run "chmod -R g+rwX #{File.join(current_path, 'public', 'rdoc')}"
    end

    task :echo_revision, :roles => :app do
       run "echo 'REVISION: ' `cat #{File.join(current_path, 'REVISION')}`"
    end

 end
