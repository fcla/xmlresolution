# -*- mode:ruby; -*-

# TODO: rcov appears to be broken on my system

require 'fileutils'
require 'rspec'
require 'rspec/core/rake_task'
require 'socket'


HOME    = File.expand_path(File.dirname(__FILE__))
LIBDIR  = File.join(HOME, 'lib')
TMPDIR  = File.join(HOME, 'tmp')

FILES   = FileList["#{LIBDIR}/**/*.rb", 'config.ru', 'app.rb']         # run yard/hanna/rdoc on these and..
DOCDIR  = File.join(HOME, 'public', 'internals')                       # ...place the html doc files here.

# require 'bundler/setup'

# These days, bundle is called automatically, if a Gemfile exists, by a lot
# of different libraries - rack and rspec among them.  Use the development
# gemfile for those things run from this Rakefile.

### ENV['BUNDLE_GEMFILE'] = File.join(HOME, 'Gemfile.development')

def dev_host
  Socket.gethostname =~ /romeo-foxtrot/
end

RSpec::Core::RakeTask.new do |task|
   task.rspec_opts = [ '--color', '--format', 'documentation' ] 
  ## task.rcov = true if Socket.gethostname =~ /romeo-foxtrot/   # do coverage tests on my devlopment box
end

# RSpec::Core::RakeTask.new

# Documentation support on deployed hosts is so iffy that we distribute our own

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

desc "Hit the restart button for apache/passenger, pow servers"
task :restart do
  sh "touch #{HOME}/tmp/restart.txt"
end

# Build local bundled Gems; 

desc "Gem bundles"
task :bundle do
  sh "rm -rf #{HOME}/bundle #{HOME}/.bundle #{HOME}/Gemfile.development.lock #{HOME}/Gemfile.lock"
  sh "mkdir -p #{HOME}/bundle"
  ### sh "cd #{HOME}; bundle --gemfile Gemfile.development install --path bundle"
  sh "cd #{HOME}; bundle --gemfile Gemfile install --path bundle"
end

desc "Make emacs tags files"
task :etags do
  files = (FileList['lib/**/*', "tools/**/*", 'views/**/*', 'spec/**/*', 'bin/**/*']).exclude('*/xmlvalidator.jar', 'spec/files', 'spec/reports')        # run yard/hanna/rdoc on these and..
  puts "Creating Emacs TAGS file"
  `xctags -e #{files}`
end


desc "deploy to darchive's production site (xmlresolution.fda.fcla.edu)"
task :darchive do
    sh "cap deploy -S target=darchive.fcla.edu:/opt/web-services/sites/xmlresolution -S who=daitss:daitss"
end

desc "deploy to development site (xmlresolution.retsinafcla.edu)"
task :retsina do
    sh "cap deploy -S target=retsina.fcla.edu:/opt/web-services/sites/xmlresolution -S who=daitss:daitss"
end

desc "deploy to ripple's test site (xmlresolution.ripple.fcla.edu)"
task :ripple do
    sh "cap deploy -S target=ripple.fcla.edu:/opt/web-services/sites/xmlresolution -S who=xmlrez:daitss"
end

desc "deploy to tarchive's coop (xmlresolution.tarchive.fcla.edu?)"
task :tarchive_coop do
    sh "cap deploy -S target=tarchive.fcla.edu:/opt/web-services/sites/coop/xmlresolution -S who=daitss:daitss"
end

defaults = [:restart, :spec]
defaults.push :etags   if dev_host

task :default => defaults
