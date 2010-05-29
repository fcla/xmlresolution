require 'xmlresolution'

include XmlResolution

configure do
  $KCODE = 'UTF8'         # Required for XML processing libraries.

  disable :logging        # Stop CommonLogger from logging to STDERR, please.

  disable :dump_errors    # This is set to true in 'classic' style apps (of which this is one) regardless of :environment; it
                          # adds a backtrace to STDERR on all raised errors (even those we properly handle). Not so good.

  set :environment,  :production            # Get some exceptional defaults.

  set :proxy,       ENV['RESOLVER_PROXY']   # Where to find the tape robot (see SiloTape and TsmExecutor).
  set :data_path,   ENV['DATA_ROOT']        # The collections and schema data live here.

  if ENV['LOG_FACILITY'].nil?
    Logger.stderr
  else
    Logger.facility  = ENV['LOG_FACILITY']
  end

  use Rack::CommonLogger, Logger.new  # Bend CommonLogger to our will...

  Logger.info "Starting #{XmlResolution.version.rev}."
  Logger.info "Initializing with data directory #{ENV['DATA_ROOT']}; caching proxy is #{ENV['RESOLVER_PROXY'] || 'off' }."
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

