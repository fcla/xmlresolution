require 'xmlresolution'
require 'datyl/config'
require 'datyl/logger' 
require 'fileutils'

include XmlResolution
include Datyl            # gets Logger interface

@@tempdir = Dir.mktmpdir

def get_config

  raise ConfigurationError, "No DAITSS_CONFIG environment variable has been set, so there's no configuration file to read"             unless ENV['DAITSS_CONFIG']
  raise ConfigurationError, "The VIRTUAL_HOSTNAME environment variable has not been set"                                               unless ENV['VIRTUAL_HOSTNAME']
  raise ConfigurationError, "The DAITSS_CONFIG environment variable points to a non-existant file, (#{ENV['DAITSS_CONFIG']})"          unless File.exists? ENV['DAITSS_CONFIG']
  raise ConfigurationError, "The DAITSS_CONFIG environment variable points to a directory instead of a file (#{ENV['DAITSS_CONFIG']})"     if File.directory? ENV['DAITSS_CONFIG']
  raise ConfigurationError, "The DAITSS_CONFIG environment variable points to an unreadable file (#{ENV['DAITSS_CONFIG']})"            unless File.readable? ENV['DAITSS_CONFIG']
  
  return Datyl::Config.new(ENV['DAITSS_CONFIG'], ENV['VIRTUAL_HOSTNAME'])
end

def do_at_exit(str1)

	  at_exit do
		  FileUtils.rm_rf(str1);
		  Logger.info "Temporary directory #{str1} deleted" 
		  #if get_config.shutdown_stats 
		  #   shutdown_stats
		  #end
		  Logger.info "Ending #{XmlResolution.version.rev}"
         end
end



configure do
  config = get_config

  #$KCODE = 'UTF8'         # Required for XML processing libraries.  #ruby 1.9.3

  disable :logging        # Stop CommonLogger from logging to STDERR, please.

  disable :dump_errors    # This is set to true in 'classic' style apps (of which this is one) regardless of :environment; it
                          # adds a backtrace to STDERR on all raised errors (even those we properly handle). Not so good.

  set :environment,  :production            # Get some exceptional defaults.

  set :raise_errors, false                  # We'll handle our own errors, thanks

  set :proxy,       config.resolver_proxy   # Where to find the tape robot (see SiloTape and TsmExecutor).
  #set :data_path,   config.data_root        # The collections and schema data live here.

  # create a unique temporary directory to hold the output files.
  #@@tempdir = Dir.mktmpdir  code move to schema_catalog.rb 
  set :data_path, @@tempdir                  # The collections and schema data live here.
    
  Logger.setup('XmlResolution', ENV['VIRTUAL_HOSTNAME'])

  if not (config.log_filename or config.log_syslog_facility)
    Logger.stderr
  end

  Logger.facility = config.log_syslog_facility  if config.log_syslog_facility
  Logger.filename = config.log_filename         if config.log_filename

  use Rack::CommonLogger, Logger.new(:info, 'Rack:')  # Bend CommonLogger to our will...

  Logger.info "Starting #{XmlResolution.version.rev}"
  Logger.info "Initializing with temp data directory #{@@tempdir}; caching proxy is #{config.resolver_proxy || 'off' }"
  defconfig = Datyl::Config.new(ENV['DAITSS_CONFIG'], 'defaults')
  #Logger.info "Using temp directory #{@@tempdir}"

  collections_dirname =  File.join(@@tempdir,"collections")
  Dir.mkdir(collections_dirname)
  Logger.info "Collections directory #{collections_dirname} created"
  schemas_dirname =  File.join(@@tempdir,"schemas")
  Dir.mkdir(schemas_dirname)
  Logger.info "Schemas directory #{schemas_dirname} created"
  do_at_exit(@@tempdir)
end

begin
  load 'lib/app/helpers.rb'
  load 'lib/app/errors.rb'
  load 'lib/app/gets.rb'
  load 'lib/app/posts.rb'
  load 'lib/app/puts.rb'
rescue ScriptError => e
  Logger.err "Initialization Error: #{e.message}"
end
