require 'xmlresolution'

include XmlResolution

def get_config
  filename = ENV['XMLRESOLUTION_CONFIG_FILE'] || File.join(File.dirname(__FILE__), 'config.yml')
  config = ResolverUtils.read_config(filename)
end


configure do
  config = get_config

  $KCODE = 'UTF8'         # Required for XML processing libraries.

  disable :logging        # Stop CommonLogger from logging to STDERR, please.

  disable :dump_errors    # This is set to true in 'classic' style apps (of which this is one) regardless of :environment; it
                          # adds a backtrace to STDERR on all raised errors (even those we properly handle). Not so good.

  set :environment,  :production            # Get some exceptional defaults.

  set :raise_errors, false                  # We'll handle our own errors, thanks

  set :proxy,       config.resolver_proxy   # Where to find the tape robot (see SiloTape and TsmExecutor).
  set :data_path,   config.data_root        # The collections and schema data live here.

  Logger.setup('XmlResolution', config.virtual_hostname)  # TODO: add vhost second arg

  if config.log_syslog_facility
    Logger.facility = config.log_syslog_facility
  else
    Logger.stderr
  end

  use Rack::CommonLogger, Logger.new(:info, 'Rack:')  # Bend CommonLogger to our will...

  Logger.info "Starting #{XmlResolution.version.rev}"
  Logger.info "Initializing with data directory #{config.data_root}; caching proxy is #{config.resolver_proxy || 'off' }"
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
