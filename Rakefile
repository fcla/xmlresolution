# -*- mode:ruby; -*-

require 'fileutils'
require 'rake'
require 'rake/rdoctask'
require 'socket'
require 'spec/rake/spectask'

require 'bundler'             # We need this for remote deploys where we want to run the spec tests.
Bundler.setup

HOME    = File.expand_path(File.dirname(__FILE__))
LIBDIR  = File.join(HOME, 'lib')
TMPDIR  = File.join(HOME, 'tmp')

FILES   = FileList["#{LIBDIR}/**/*.rb", 'config.ru', 'app.rb']         # run yard/hanna/rdoc on these and..
DOCDIR  = File.join(HOME, 'public', 'internals')                       # ...place the html doc files here.

def dev_host
  Socket.gethostname =~ /romeo-foxtrot/
end

# cleanup handling of CI & spec dependencies

spec_dependencies = []

# Working with continuous integration.  The CI servers out
# there.... Sigh... Something that should be so easy...let's start
# with ci/reporter...
#
# TODO: conditionally add to the spec tests, and send the output to
# a web service

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
  task.spec_opts = [ '--format', 'specdoc' ]    # ci/reporter is getting in the way of this being used.
  task.libs << 'lib'
  task.libs << 'spec'
  task.rcov = true if dev_host   # do coverage tests on my devlopment box
end


desc "Generate documentation from libraries - try yardoc, hanna, rdoc, in that order."
task :docs do

  yardoc  = `which yardoc 2> /dev/null`
  hanna   = `which hanna  2> /dev/null`
  rdoc    = `which rdoc   2> /dev/null`

  if not yardoc.empty?
    command = "yardoc --quiet --private --protected --title 'XML Resolution Service' --output-dir #{DOCDIR} #{FILES}"
  elsif not hanna.empty?
    command = "hanna --quiet --main XmlResolution --op #{DOCDIR} --inline-source --all --title 'XML Resolution' #{FILES}"
  elsif not rdoc.empty?
    command = "rdoc --quiet --main XmlResolution --op #{DOCDIR} --inline-source --all --title 'XML Resolution' #{FILES}"
  else
    command = nil
  end

  if command.nil?
    puts "No documention helper (yardoc/hannah/rdoc) found, skipping the 'doc' task."
  else
    FileUtils.rm_rf FileList["#{DOCDIR}/**/*"]
    puts "Creating docs with #{command.split.first}."
    `#{command}`
  end
end

desc "Maintain the sinatra tmp directory for automated restart (passenger phusion pays attention to tmp/restart.txt)."
task :restart do
  mkdir TMPDIR unless File.directory? TMPDIR
  restart = File.join(TMPDIR, 'restart.txt')
  if not (File.exists?(restart) and `find  #{FILES} -type f -newer "#{restart}" 2> /dev/null`.empty?)
    puts "Indicating a restart is in order."
    File.open(restart, 'w') { |f| f.write "" }
  end
end

desc "Make emacs tags files"
task :etags do
  files = (FileList['lib/**/*', "tools/**/*", 'views/**/*', 'spec/**/*', 'bin/**/*']).exclude('*/xmlvalidator.jar', 'spec/files', 'spec/reports')        # run yard/hanna/rdoc on these and..
  puts "Creating Emacs TAGS file"
  `xctags -e #{files}`
end

defaults = [:restart, :spec]
defaults.push :etags   if dev_host

task :default => defaults
