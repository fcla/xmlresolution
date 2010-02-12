# Add our lib directory so passenger/sinatra can find it:

$:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'sinatra'
require 'app'

run Sinatra::Application
