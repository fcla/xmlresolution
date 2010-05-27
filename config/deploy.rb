 set :application,       "xmlresolution"
 set :domain,            "xmlresolution.ripple.sacred.net"
 set :repository,        "http://github.com/daitss/xmlresolution.git"
 set :use_sudo,          false
 set :deploy_to,         "/opt/web-services/sites/#{application}"
 set :scm,               "git"
 set :user,              "xmlrez"


 role :app, domain
 role :web, domain
 role :db,  domain, :primary => true

# After we've successfully updated, we run these tasks: layout sets up
# the directory structure and runs bundle to install our own gem
# dependencies; rdoc builds library doco; restart touches the file
# that instructs passenger phusion to restart the app.

after "deploy:update", "deploy:layout", "deploy:rdoc", "deploy:restart"

 namespace :deploy do
   
   task :start do  # setup sudo command to restart apache?  doesn't seem necessary yet.
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
     
     ['collections', 'schemas'].each do |dir|       # want to preserve existing data, so let's keep these in the shared directory and link into them.
       realname = File.join(shared_path, dir)
       linkname = File.join(current_path, 'data')
       run "ln -s #{realname} #{linkname}"
       run "chmod -R ug+rwX #{realname}" 
     end

     run "cd #{current_path}; bundle install #{File.join(shared_path, "vendor")}"
   end
   
   task :rdoc, :roles => :app do                     # generate fresh rdoc.
     run "cd #{current_path}; rake rdoc"
     run "chmod -R ug+rwX #{File.join(current_path, 'public', 'rdoc')}"
   end
   
 end
 



# remote deployed server: make sure we have rake in our path
