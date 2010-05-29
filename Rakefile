# -*- mode:ruby; -*-

require 'fileutils'
require 'rake'
require 'rake/rdoctask'
require 'socket'
require 'spec/rake/spectask'

HOME    = File.expand_path(File.dirname(__FILE__))
LIBDIR  = File.join(HOME, 'lib')
TMPDIR  = File.join(HOME, 'tmp')

PUBLIC_DOCS = File.join(HOME, 'public', 'internals')

def dev_host
  Socket.gethostname =~ /romeo-foxtrot/
end

spec_dependencies = []

# Working with continuous integration.  The CI servers out
# there.... Sigh... Something that should be so easy...let's start
# with ci/reporter...

begin
  require 'ci/reporter/rake/rspec' 
rescue LoadError => e
else
  spec_dependencies.push "ci:setup:rspec"
end  

begin
  require 'ci/reporter/rake/cucumber' 
rescue LoadError => e
else
  spec_dependencies.push "ci:setup:cucumber"
end  

task :spec => spec_dependencies

Spec::Rake::SpecTask.new do |task|
  task.libs << 'lib'
  task.libs << 'spec'
  task.rcov = true if dev_host   # do coverage tests on my devlopment box
end


defaults = [:spec, :restart]

defaults.push :tags if dev_host

begin
  require 'yard'
  YARD::Rake::YardocTask.new do |task|
    task.files   = ['lib/**/*.rb']  
    task.options = ['--private', '--protected', '--title', 'XML Resolution Service', '--output-dir', PUBLIC_DOCS ]
  end
  defaults.push :yard
rescue LoadError => e
  STDERR.puts 
end

# Assumes you're keeping your code in a lib directory - adjust accordingly:

desc "Generate rdoc documentation from libraries - we added --inline and --all options and --op rdoc options"
task :rdoc do

  COMMAND = `which hanna`.empty? ? 'rdoc' : 'hanna'

  begin
    FileUtils.rm_rf PUBLIC_DOCS
    chdir LIBDIR
    command = "#{COMMAND} --main XmlResolution --op #{File.join(HOME, 'public/internals')} --inline-source --all --title 'XML Resolution' #{Dir['*.rb'].join(' ')}  #{Dir['xmlresolution/*.rb'].join(' ')}"
    puts command
    `#{command}`    
  rescue => e
    raise e
  ensure 
    chdir HOME
  end
end

desc "Maintain the sinatra tmp directory for automated restart (passenger phusion pays attention to tmp/restart.txt) - only restarts if necessary"
task :restart do
  mkdir TMPDIR unless File.directory? TMPDIR
  restart = File.join(TMPDIR, 'restart.txt')     

  files="app.rb config.ru lib/ public/ views/"

  if not (File.exists?(restart) and `find  #{files} -type f -newer "#{restart}" 2> /dev/null`.empty?)
    File.open(restart, 'w') { |f| f.write "" }
  end  
end

namespace "tags" do
  files = FileList['**/*.rb', '**/*.ru'].exclude("pkg")
  task :emacs => files do
    puts "Making Emacs TAGS file"
    sh "xctags -e #{files}", :verbose => false
  end
end

task :tags => ["tags:emacs"]


task :default => defaults

