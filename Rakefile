require 'rake'
require 'rake/rdoctask'
require 'spec/rake/spectask'

Spec::Rake::SpecTask.new do |t|
  t.libs << 'lib'
  t.libs << 'spec'
  # t.rcov = true
end

HOME   = File.dirname(__FILE__)
LIBDIR = File.join(HOME, 'lib')
TMPDIR = File.join(HOME, 'tmp')

# Assumes you're keeping your code in a lib directory - adjust accordingly:

desc "Generate rdoc documentation from libraries - we added --inline and --all options and --op rdoc options"
task :rdoc do
  chdir File.join(HOME, 'xmlresolver')
  begin
     command = "rdoc --op #{File.join(HOME, 'public/rdoc')} --inline --all #{Dir['*.rb'].join(' ')}"
     puts command
     `#{command}`    
  rescue => e
    raise e
  ensure 
    chdir HOME
  end
end

desc "Maintain a sinatra temp directory for automated restart (nginx/passenger fusion pays attention to tmp/restart.txt)"
task :restart do
  mkdir TMPDIR unless File.directory? TMPDIR
  restart = File.join(TMPDIR, 'restart.txt')     
  if not (File.exists?(restart) and `find "#{HOME}" -type f -newer "#{restart}" 2> /dev/null`.empty?)
    File.open(restart, 'w') { |f| f.write "" }
  end  
end

task :default => [:spec]
