require 'log4r'
require 'syslog'
require 'log4r/outputter/syslogoutputter'
require 'log4r/outputter/fileoutputter'
require 'log4r/outputter/rollingfileoutputter'
require 'xmlresolution/exceptions'
require 'xmlresolution/utils'


 

# TODO:  the whole prefix thing is lame - rip it out, and rip out the @env environment/commonlogger requirement.

module XmlResolution

  # Initial Author: Randy Fischer (rf@ufl.edu) for DAITSS
  #
  # Logging web service actions using using log4r with a
  # Rack::CommonLogger tie-in.
  #
  # Example use:
  #
  #  require 'logger'
  #
  #  Logger.logname  = "XmlResolution"
  #  Logger.filename = "myfile.log"
  #  ...
  #  get '/tmp' do
  #     Logger.warn "can't create temporary file for request.", @env
  #     halt [ 400, {}, 'oops' ]
  #  end
  #  ...
  #  get '/temp' do
  #     Logger.err  "the machine room appears to be on fire.", @env
  #     "451 degrees Fahrenheit"
  #  end
  #
  # This might produce in "myfile.log" the following:
  #
  #   WARN XmlResolution: "GET /tmp" can't create temporary file for request.
  #  ERROR XmlResolution: "GET /temp" the machine room appears to be on fire.
  #
  # The env variable is a hash, typically you'll use @env
  # from the Sinatra environment.  Anything that provides the
  # PEP 333 standard set of CGI environment variables is
  # best (HTTP_SERVER, PATH_INFO, etc), but an empty hash will work
  # in a pinch (and is the default).
  #
  # Here's an example of using a Logger object to direct Rack::CommonLogger to write
  # to both a file and syslog.
  #
  #  require 'logger'
  #
  #  Logger.logname  = 'XmlResolution'
  #  Logger.filename = '/tmp/myfile.log'
  #  Logger.facility = :LOG_LOCAL2
  #  use Rack::CommonLogger, Logger.new

  class Logger

    # This class variable lets us know if is safe to proceed; a Log4r
    # logging object has been set up and registered.  It must be set by
    # a call to Logger.initialize_maybe - which one of the class
    # initializers - Logger.filename=, Logger.facility= or Logger.stderr -
    # will take care of.

    @@initialized = false
    @@logname     = 'XmlResolution'

    # Logger.logname = NAME
    #
    # Intialize the logging system with the identifier NAME, required
    # before anything else is done.
    #

    def Logger.initialize_maybe
      if not @@initialized
        Log4r::Logger.new @@logname
        @@initialized = true
      end
    end

    # Logger.filename = FILEPATH
    #
    # Intialize the logging system to write to the file named by
    # string FILEPATH.
    #
    # We envision a number of ways to initialize this class before
    # use. We can set up for logging to files, syslog, stderr, or any
    # combination. At least one of them must be done before any actual
    # logging occurs.

    def Logger.filename= filepath
      Logger.initialize_maybe
      ResolverUtils.check_directory "The log directory", File.dirname(filepath)
      Log4r::Logger[@@logname].add Log4r::FileOutputter.new(Logger.process_name, { :filename => filepath, :trunc => false })
      filepath
    end

    # Logger.stderr
    #
    # Initialize the logging system to write to STDERR.

    def Logger.stderr
      Logger.initialize_maybe
      Log4r::Logger[@@logname].add Log4r::StderrOutputter.new(Logger.process_name)
    end

    # Logger.facility = FACILITY
    #
    # Intialize the logging system to write to syslog, using the
    # the symbol FACILTIY to specify the facility to use. Normally
    # one uses a local facility code (but strings will work):
    #
    #    :LOG_LOCAL0
    #    :LOG_LOCAL1
    #       ...
    #    :LOG_LOCAL7
    #
    # A typical syslog.conf entry using :LOG_LOCAL2 might look like this:
    #
    #    local2.error   /var/log/xmlresolution.error.log
    #    local2.warn    /var/log/xmlresolution.warn.log
    #    local2.info    /var/log/xmlresolution.info.log
    #
    # In the case of Mac OSX Snow Leopard, the above syslog.conf entry
    # means that a Logger.error(message) will get logged to
    # xmlresolution.error.log, xmlresolution.warn.log, and
    # xmlresolution.info.log.  Logger.warn(message) gets logged to
    # xmlresolution.warn.log and xmlresolution.info.log.
    # Logger.info(message) will go to xmlresolution.info.log.  Other
    # syslog deamons on other systems and alternative configurations
    # behave significantly differently.  But that's not your problem.

    def Logger.facility= facility
      Logger.initialize_maybe
      Log4r::Logger[@@logname].add Log4r::SyslogOutputter.new(Logger.process_name, 'facility' => eval("Syslog::#{facility.to_s.upcase}"))
    rescue => e
      raise XmlResolution::ConfigurationError, "Error initializing syslog logging using facility code #{facility}: e.message"
    else
      facility
    end

    # Logger.err MESSAGE, [ ENV ]
    #
    # Log an error message MESSAGE, a string; The hash
    # ENV is typically the Sinatra @env object, but any hash with the
    # common PEP 333 keys could be used.

    def Logger.err message, env = {}
      Log4r::Logger[@@logname].error prefix(env) + message.chomp
    end

    # Logger.warn MESSAGE, [ ENV ]
    #
    # Log a warning message MESSAGE, a string; The hash
    # ENV is typically the Sinatra @env object, but any hash with the
    # common PEP 333 keys could be used.

    def Logger.warn message, env = {}
      Log4r::Logger[@@logname].warn  prefix(env) + message.chomp
    end

    # Logger.info MESSAGE, [ ENV ]
    #
    # Log an informative message MESSAGE, a string; The hash
    # ENV is typically the Sinatra @env object, but any hash with the
    # common PEP 333 keys could be used.

    def Logger.info message, env = {}
      Log4r::Logger[@@logname].info  prefix(env) + message.chomp
    end

    # While we normally use the class methods to write our own log entries, we
    # also have an object we can instantiate for Rack::CommonLogger to
    # use. For example:
    #
    #  Logger.logname  = 'XmlResolutionService'
    #  Logger.filename = 'my.log'
    #  use Rack:CommonLogger, Logger.new

    def initialize
    end

    # log.write MESSAGE
    #
    # Rack::CommonLogger can be told to use as a logger any object that has a write method on
    # it. See the Logger#new method for an example of its use.

    def write message
      Log4r::Logger[@@logname].info message.chomp
    end

    private

    # prefix ENV
    #
    # Create an apache-style "METHOD /uri"  string, if possible, from the environment ENV.
    # ENV is expected to be @env from a rack application,
    #
    # Note that the object method #write will not use this.

    def Logger.prefix env
      return '' if env['REQUEST_METHOD'].nil? and env['PATH_INFO'].nil?
      sprintf('"%s %s%s" ',
              env['REQUEST_METHOD'],
              env['PATH_INFO'],
              (env['QUERY_STRING'].nil? or env['QUERY_STRING'].empty?) ? '' : '?' + env['QUERY_STRING'])
    end

    def Logger.process_name
      File.basename($0)
    end

  end # of class
end # of module


