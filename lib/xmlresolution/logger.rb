require 'log4r'
# require 'syslog'
# require 'log4r/outputter/syslogoutputter'
# require 'log4r/outputter/fileoutputter'
require 'log4r/outputter/rollingfileoutputter'
require 'xmlresolution/exceptions'

module XmlResolution

  class Logger

    # We envision a number of ways to initialize this: files, syslog,
    # etc. At least one of them must be done first. Initialized lets
    # us know we can proceed.

    @@initialized = false

    def Logger.filename= filepath
      Log4r::Logger.new 'XmlResolution' unless Log4r::Logger['XmlResolution']
      Log4r::Logger['XmlResolution'].add Log4r::FileOutputter.new('XmlResolution', { :filename => filepath, :trunc => false })
      @@initialized = true
    end


    # Write an error message MESSAGE, a string, to the log; The hash
    # ENV is typically the sinatra env object, but any hash with the
    # common PEP 333 keys could be used.

    def Logger.err env, message
      Log4r::Logger['XmlResolution'].error apache_common_prefix(env) + message
    end

    # Write a warning message MESSAGE, a string, to the log; The hash
    # ENV is typically the sinatra env object, but any hash with the
    # common PEP 333 keys could be used.

    def Logger.warn env, message
      Log4r::Logger['XmlResolution'].warn  apache_common_prefix(env) + message
    end

    # Write an informative message MESSAGE, a string, to the log; The hash
    # ENV is typically the sinatra env object, but any hash with the
    # common PEP 333 keys could be used.

    def Logger.info env, message
      Log4r::Logger['XmlResolution'].info  apache_common_prefix(env) + message
    end

    # While we use the class methods to write our own log entries, we
    # also have an object we can instantiate for Rack::CommonLogger to 
    # use. For example:
    #
    #  XmlResolution::Logger.filename = 'my.log'
    #  use Rack:CommonLogger, XmlResolution::Logger.new
    #  

    def initialize
      raise LogError, "The class has not been initialized with a log target yet. See XmlResolution::Logger.filename= and bretheren." unless @@initialized
    end

    # Rack::CommonLogger can be told to use any logger that has a write method on
    # it - here it is:

    def write message
      Log4r::Logger['XmlResolution'].info message.chomp
    end


    private

    # For our class methods, we'd like to use the same format that the
    # Rack::CommonLogger uses. This method produces that format, if
    # possible. Swiped from rack/lib/commonlogger.rb, mostly.  Note
    # that the object method #write will not use this.

    def Logger.apache_common_prefix env

      sprintf('%s - %s [%s] "%s %s%s %s" ',
              env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
              env["REMOTE_USER"] || "-",
              Time.now.strftime("%d/%b/%Y:%H:%M:%S"),
              env["REQUEST_METHOD"],
              env["PATH_INFO"],
              (env["QUERY_STRING"].nil? or env["QUERY_STRING"].empty?) ? "" : "?" + env["QUERY_STRING"],
              env["HTTP_VERSION"])
    end


  end # of class
end # of module

