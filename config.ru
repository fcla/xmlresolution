# Add our lib directory so passenger/sinatra can find it:

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

# Works OK - commonlogger will use logs/test.log *and* the apache log files.
#
# log = File.new("logs/test.log", "w")
# STDOUT.reopen(log)
# STDERR.reopen(log)


# This doesn't work at all (the File.new creates the file of course)
# It doesn't make any (external) difference if sinatra is required before or after it.
#
# log = File.new("logs/common.log", "a+")
# use Rack::CommonLogger, log

require 'sinatra'
require 'app'

run Sinatra::Application
