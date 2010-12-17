require 'log4r'
require 'socket'
require 'syslog'
require 'log4r/outputter/syslogoutputter'
require 'log4r/outputter/fileoutputter'
require 'log4r/outputter/rollingfileoutputter'

# TODO:  the whole prefix thing is lame - rip it out, and rip out the environment requirement.


# Initial Author: Randy Fischer (rf@ufl.edu) for DAITSS
# 
# Logging web service actions using using log4r with a
# Rack::CommonLogger tie-in. 
#
# Example use:
#
#  require 'logger'
#  
#  Logger.setup("XmlResolution", "xmlresolution.example.com")
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
#  Logger.logname  = 'xmlresolution.example.com'
#  Logger.filename = '/tmp/myfile.log'
#  Logger.facility = :LOG_LOCAL2
#  use Rack::CommonLogger, Logger.new

class Logger
  
  # This class variable lets us know if is safe to proceed; a Log4r
  # logging object has been set up and registered.  It must be set by
  # a call to Logger.initialize_maybe - which one of the class
  # initializers - Logger.filename=, Logger.facility= or Logger.stderr - 
  # will take care of.
  
  @@log_name     = nil
  @@process_name = nil

  # Logger.setup process_name, service_name
  #
  # Intialize the logging system.  Until called, all logging is 
  # a no-op.
  #
  # In logging the arguments are used as follows:
  #
  # Dec 15 09:32:21 romeo-foxtrot PROCESS_NAME[45933]:  INFO SERVICE_NAME...
  #
  # It is recommented the virtual host name be used for service_name
  # and the general type service for process_name (e.g. XmlResolution,
  # SiloPool, StoreMaster), so you might see a log entry like:
  #
  # Dec 15 12:38:26 romeo-foxtrot SiloPool[51470]:  INFO silos.test.fcla.edu: 

  def Logger.setup(process_name, service_name = Socket.gethostname)
    @@log_name     = service_name
    @@process_name = process_name
    Log4r::Logger.new @@log_name
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
    return unless (@@log_name and @@process_name)
    Log4r::Logger[@@log_name].add Log4r::FileOutputter.new(@@process_name, { :filename => filepath, :trunc => false })
    filepath
  end
  
  # Logger.stderr
  #
  # Initialize the logging system to write to STDERR.
  
  def Logger.stderr
    return unless (@@log_name and @@process_name)
    Log4r::Logger[@@log_name].add Log4r::StderrOutputter.new(@@process_name)
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
    return unless (@@log_name and @@process_name)
    Log4r::Logger[@@log_name].add Log4r::SyslogOutputter.new(@@process_name, 'facility' => eval("Syslog::#{facility.to_s.upcase}"))
    facility
  end
  
  # Logger.err MESSAGE, [ ENV ]
  #
  # Log an error message MESSAGE, a string; The hash
  # ENV is typically the Sinatra @env object, but any hash with the
  # common PEP 333 keys could be used.
  
  def Logger.err message, env = {}
    return unless (@@log_name and @@process_name)
    Log4r::Logger[@@log_name].error prefix(env) + message.chomp
  end
  
  # Logger.warn MESSAGE, [ ENV ]
  #
  # Log a warning message MESSAGE, a string; The hash
  # ENV is typically the Sinatra @env object, but any hash with the
  # common PEP 333 keys could be used.
  
  def Logger.warn message, env = {}
    return unless (@@log_name and @@process_name)
    Log4r::Logger[@@log_name].warn  prefix(env) + message.chomp
  end
  
  # Logger.info MESSAGE, [ ENV ]
  #
  # Log an informative message MESSAGE, a string; The hash
  # ENV is typically the Sinatra @env object, but any hash with the
  # common PEP 333 keys could be used.
  
  def Logger.info message, env = {}
    return unless (@@log_name and @@process_name)
    Log4r::Logger[@@log_name].info  prefix(env) + message.chomp
  end
  
  # While we normally use the class methods to write our own log entries, we
  # also have an object we can instantiate for Rack::CommonLogger to 
  # use. For example:
  #
  #  Logger.setup('XmlResolutionService', 'xrez.example.com')
  #  Logger.filename = 'my.log'
  #  use Rack:CommonLogger, Logger.new

  def initialize
    raise "The logging system has not been setup: use Logger.setup(service, hostname)." if (@@log_name.nil? or @@process_name.nil?)
  end  
  
  # log.write MESSAGE
  #
  # Rack::CommonLogger can be told to use as a logger any object that has a write method on
  # it. See the Logger#new method for an example of its use.
  
  def write message
    Log4r::Logger[@@log_name].info message.chomp
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

  
end # of class
