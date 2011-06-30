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
  # a call to Logger.setup, followed by one or more of the log output
  # initializers, namely Logger.filename=, Logger.facility= or
  # Logger.stderr.

  @@virtual_hostname = nil
  @@service_name     = nil

  # Logger.setup service_name, virtual_hostname
  #
  # Intialize the logging system.  Until called, all logging is
  # a no-op.
  #
  # In logging the arguments are used as follows:
  #
  # Dec 15 12:38:26 romeo-foxtrot SiloPool[51470]:  INFO silos.test.fcla.edu
  #                               --------               -------------------
  #                               @@service_name         @@virtual_hostname
  #
  # It is recommented the virtual host name of the service be used for
  # @@virtual_hostname but it will default to the hostname of the
  # computer; @@service_name should not have any spaces, so the logs
  # can be conveniently parsed.


  def Logger.setup(service_name, virtual_hostname = Socket.gethostname)
    @@virtual_hostname = virtual_hostname
    @@service_name     = service_name

    Log4r::Logger.new @@virtual_hostname
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
    return unless (@@virtual_hostname and @@service_name)
    Log4r::Logger[@@virtual_hostname].add Log4r::FileOutputter.new(@@service_name, { :filename => filepath, :trunc => false })
    filepath
  end

  # Logger.stderr
  #
  # Initialize the logging system to write to STDERR.

  def Logger.stderr
    return unless (@@virtual_hostname and @@service_name)
    Log4r::Logger[@@virtual_hostname].add Log4r::StderrOutputter.new(@@service_name)
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
  #    :LOG_LOCAL9
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
    return unless (@@virtual_hostname and @@service_name)
    facility = 'LOG_' + facility unless facility =~ /^LOG_/
    Log4r::Logger[@@virtual_hostname].add Log4r::SyslogOutputter.new(@@service_name, 'facility' => eval("Syslog::#{facility.to_s.upcase}"))
    facility
  end

  # Logger.err MESSAGE, [ ENV ]
  #
  # Log an error message MESSAGE, a string; The hash
  # ENV is typically the Sinatra @env object, but any hash with the
  # common PEP 333 keys could be used.

  def Logger.err message, env = {}
    return unless (@@virtual_hostname and @@service_name)
    Log4r::Logger[@@virtual_hostname].error prefix(env) + message.chomp
  end

  # Logger.warn MESSAGE, [ ENV ]
  #
  # Log a warning message MESSAGE, a string; The hash
  # ENV is typically the Sinatra @env object, but any hash with the
  # common PEP 333 keys could be used.

  def Logger.warn message, env = {}
    return unless (@@virtual_hostname and @@service_name)
    Log4r::Logger[@@virtual_hostname].warn  prefix(env) + message.chomp
  end

  # Logger.info MESSAGE, [ ENV ]
  #
  # Log an informative message MESSAGE, a string; The hash
  # ENV is typically the Sinatra @env object, but any hash with the
  # common PEP 333 keys could be used.

  def Logger.info message, env = {}
    return unless (@@virtual_hostname and @@service_name)
    Log4r::Logger[@@virtual_hostname].info  prefix(env) + message.chomp
  end

  # While we normally use the class methods to write our own log
  # entries, we also have an object we can instantiate for
  # Rack::CommonLogger or DataMapper::Logger to use. For example:
  #
  #  Logger.setup('XmlResolutionService', 'xrez.example.com')
  #  Logger.filename = 'my.log'
  #  use Rack:CommonLogger, Logger.new(:info, 'Rack:')
  #  DataMapper::Logger(Logger.new(:info, 'DataMapper:'), :debug)

  @level = nil
  @tag   = nil

  def initialize level = :info, tag = ''
    raise "Bad argument: if specified, the first argument must be one of :info, :warn, :error, but was :#{level}" unless [:info, :warn, :error].include? level
    raise "Bad argument: if specified, the second argument must be a simple string, but was a #{tag.class}" unless tag.class == String
    raise "The logging system has not been setup: use Logger.setup(service, hostname)." if (@@virtual_hostname.nil? or @@service_name.nil?)
    @level = level
    @tag   = tag.length > 0 ? tag : nil
  end

  # log.write MESSAGE
  #
  # Rack::CommonLogger can be told to use as a logger any object that has a write method on
  # it. See the Logger#new method for an example of its use.

  def write message
    Log4r::Logger[@@virtual_hostname].send(@level, @tag ? "#{@tag} #{message.chomp}" : message.chomp)
  end

  private

  # prefix ENV
  #
  # Create an apache-style "METHOD /uri"  string, if possible, from the environment ENV.
  # ENV is expected to be @env from a rack application
  #
  # Note that the object method #write will not use this.

  def Logger.prefix env
    return '' if env['REQUEST_METHOD'].nil? or env['PATH_INFO'].nil?

    sprintf('%s %s %s %s "%s%s"',
            env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
            env["REMOTE_USER"] || "-",
            env["SERVER_PROTOCOL"],
            env["REQUEST_METHOD"],
            env["PATH_INFO"],
            env["QUERY_STRING"].empty? ? "" : "?" + env["QUERY_STRING"]
            )
  end


end # of class
