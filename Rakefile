require 'fileutils'
require 'rake'
require 'rake/rdoctask'
require 'socket'
require 'spec/rake/spectask'

spec_dependencies = []

# Working with continuous integration.  What a pile of steaming monkey
# shit are the CI servers out there.... Something that should be so
# easy...let's start with ci/reporter...

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
  task.rcov = true if Socket.gethostname =~ /romeo-foxtrot/   # do coverage tests on my devlopment box
end

task :tags => ["tags:emacs"]

HOME    = File.expand_path(File.dirname(__FILE__))
LIBDIR  = File.join(HOME, 'lib')
TMPDIR  = File.join(HOME, 'tmp')
RDOCDIR = File.join(HOME, 'public', 'rdoc')

# Assumes you're keeping your code in a lib directory - adjust accordingly:

desc "Generate rdoc documentation from libraries - we added --inline and --all options and --op rdoc options"
task :rdoc do

  DIAGRAM = ''
  COMMAND = `which hanna`.empty? ? 'rdoc' : 'hanna'

  # DIAGRAM = `which dot`.empty?   ? '' : '--diagram'
  # COMMAND = 'rdoc'

  begin
    FileUtils.rm_rf RDOCDIR
    chdir LIBDIR
    # #{Dir['app/*.rb'].join(' ')}
    command = "#{COMMAND} #{DIAGRAM} --main XmlResolution --op #{File.join(HOME, 'public/rdoc')} --inline-source --all --title 'XML Resolution' #{Dir['*.rb'].join(' ')}  #{Dir['xmlresolution/*.rb'].join(' ')}"
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

module Tags
  RUBY_FILES = FileList['**/*.rb', '**/*.ru'].exclude("pkg")
end

namespace "tags" do
  task :emacs => Tags::RUBY_FILES do
    puts "Making Emacs TAGS file"
    sh "xctags -e #{Tags::RUBY_FILES}", :verbose => false
  end
end

task :tags => ["tags:emacs"]

# TODO: do subsequent tasks kick off if a preceding one fails?

task :default => [:spec, :rdoc, :restart]
