 set :application,       "xmlresolution"
 set :domain,            "xmlresolution.dev.fcla.edu"
 set :repository,        "git@github.com:daitss/xmlresolution.git"
 set :use_sudo,          false
 set :deploy_to,         "/opt/web-services/#{application}"
 set :scm,               "git"

 role :app, domain
 role :web, domain
 role :db,  domain, :primary => true

after "deploy:update", "deploy:layout", "deploy:rdoc", "deploy:restart"

 namespace :deploy do

    task :start do  # TODO: setup sudo command to restart apache?  doesn't seem necessary yet.
    end

    task :stop do
    end

    task :restart, :roles => :app, :except => { :no_release => true } do
      run "touch #{File.join(current_path, 'tmp', 'restart.txt')}"
    end

   task :layout, :roles => :app do

     [ 'data', 'public'].each do |dir|                # might not be in git, since these are empty. 
       pathname = File.join(current_path, dir)
       run "mkdir -p #{pathname}"       
       run "chmod -R ug+rwX #{pathname}" 
     end

     ['collections', 'schemas'].each do |dir|         # want to preserve existing data, so let's keep in the shared data and link into it
       realname = File.join(shared_path, dir)
       linkname = File.join(current_path, 'data')
       run "ln -s #{realname} #{linkname}"
       run "chmod -R ug+rwX #{realname}" 
     end

    end

    task :rdoc, :roles => :app do                     # generate fresh rdoc.
       run "cd #{current_path}; rake rdoc"
       run "chmod -R g+rwX #{File.join(current_path, 'public', 'rdoc')}"
    end

 end
