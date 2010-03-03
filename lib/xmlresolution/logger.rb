require 'log4r'
require 'syslog'
require 'log4r/outputter/syslogoutputter'
require 'log4r/outputter/fileoutputter'
require 'log4r/outputter/rollingfileoutputter'
require 'xmlresolution'

module XmlResolution

  # Initial Author: Randy Fischer (rf@ufl.edu) for DAITSS
  # 
  # Logging web service actions using using log4r with a
  # Rack::CommonLogger tie-in.  The log output is roughly
  # comparable to Apache's common log format.  
  #
  # Example use:
  #
  #  require 'xmlresolution'
  #  include XmlResolution
  #  
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
  #
  # This might produce in "myfile.log" the following:
  #
  #   WARN XmlResolution: 127.0.0.1 - - [01/Mar/2010:15:24:43] "GET /tmp" can't create temporary file for request.
  #  ERROR XmlResolution: 127.0.0.1 - - [01/Mar/2010:15:25:01] "GET /temp" the machine room appears to be on fire.
  #
  # The env variable is a hash, typically you'll use @env
  # from the Sinatra environment.  Anything that provides the
  # PEP 333 standard set of CGI environment variables is  
  # best (HTTP_SERVER, PATH_INFO, etc), but an empty hash will work
  # in a pinch (and is the default).
  #
  # Here's an example of using a Logger object to direct Rack::CommonLogger to write
  # to both a file and syslogd:
  #
  #  require 'xmlresolution'
  #  include XmlResolution
  #  
  #  Logger.filename = "myfile.log"
  #  Logger.facility = :LOG_LOCAL0
  #  use Rack::CommonLogger, Logger.new
  

  class Logger

    # This class variable lets us know if is safe to proceed; a Log4r
    # logging object has been set up and registered.

    @@initialized = false

    # XmlResolution::Logger.filename = FILEPATH
    #
    # Intialize the logging system to write to the file named by
    # string FILEPATH.
    #
    # We envision a number of ways to initialize this class before
    # use. We can set up for logging to files, syslog, stderr, or any
    # combination. At least one of them must be done before any actual
    # logging occurs.  

    def Logger.filename= filepath
      Log4r::Logger.new 'XmlResolution' unless Log4r::Logger['XmlResolution']
      Log4r::Logger['XmlResolution'].add Log4r::FileOutputter.new($0, { :filename => filepath, :trunc => false })
      @@initialized = true
    end

    
    # XmlResolution::Logger.stderr
    #
    # Initialize the logging system to write to STDERR.

    def Logger.stderr
      Log4r::Logger.new 'XmlResolution' unless Log4r::Logger['XmlResolution']
      Log4r::Logger['XmlResolution'].add Log4r::StderrOutputter.new($0)
      @@initialized = true
    end

    # XmlResolution::Logger.facility = FACILITY
    #
    # Intialize the logging system to write to syslog, using the
    # the symbol FACILTIY to specify the facility to use. Normally
    # one uses a local facility code:
    #
    #    :LOG_LOCAL0
    #    :LOG_LOCAL1
    #    :LOG_LOCAL2
    #    :LOG_LOCAL3
    #    :LOG_LOCAL4
    #    :LOG_LOCAL5
    #    :LOG_LOCAL6
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
    # behave significantly differently.

    def Logger.facility= facility
      Log4r::Logger.new 'XmlResolution' unless Log4r::Logger['XmlResolution']
      Log4r::Logger['XmlResolution'].add Log4r::SyslogOutputter.new($0, 'facility' => eval("Syslog::#{facility.to_s.upcase}"))
      @@initialized = true
    end

    # Logger.err MESSAGE, [ ENV ]
    #
    # Log an error message MESSAGE, a string; The hash
    # ENV is typically the Sinatra env object, but any hash with the
    # common PEP 333 keys could be used.

    def Logger.err message, env = {}
      Log4r::Logger['XmlResolution'].error apache_common_prefix(env) + message
    end

    # Logger.warn MESSAGE, [ ENV ]
    #
    # Log a warning message MESSAGE, a string; The hash
    # ENV is typically the Sinatra env object, but any hash with the
    # common PEP 333 keys could be used.

    def Logger.warn message, env = {}
      Log4r::Logger['XmlResolution'].warn  apache_common_prefix(env) + message
    end

    # Logger.info MESSAGE, [ ENV ]
    #
    # Log an informative message MESSAGE, a string; The hash
    # ENV is typically the Sinatra env object, but any hash with the
    # common PEP 333 keys could be used.

    def Logger.info message, env = {}
      Log4r::Logger['XmlResolution'].info  apache_common_prefix(env) + message
    end

    # While we normally use the class methods to write our own log entries, we
    # also have an object we can instantiate for Rack::CommonLogger to 
    # use. For example:
    #
    #  XmlResolution::Logger.filename = 'my.log'
    #  use Rack:CommonLogger, XmlResolution::Logger.new

    def initialize
      raise LogError, "The class has not been initialized with a log target yet. See XmlResolution::Logger.filename= and bretheren." unless @@initialized
    end

    # log.write MESSAGE
    #
    # Rack::CommonLogger can be told to use as a logger any object that has a write method on
    # it. See the Logger#new method for an example of its use.

    def write message
      Log4r::Logger['XmlResolution'].info message.chomp
    end

    private

    # apache_common_prefix ENV
    #
    # For our class methods, we'd like to use roughly the same format
    # that the Rack::CommonLogger uses. This method produces that
    # format, if possible. Swiped from rack/lib/commonlogger.rb,
    # mostly.  Note that the object method #write will not use this.

    def Logger.apache_common_prefix env

      sprintf('%s - %s [%s] "%s %s%s" ',
              env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
              env["REMOTE_USER"] || "-",
              Time.now.strftime("%d/%b/%Y:%H:%M:%S"),
              env["REQUEST_METHOD"],
              env["PATH_INFO"],
              (env["QUERY_STRING"].nil? or env["QUERY_STRING"].empty?) ? "" : "?" + env["QUERY_STRING"])
    end
  end # of class
end # of module

