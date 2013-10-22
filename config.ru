# -*- mode: ruby; -*-

require 'bundler/setup'

#p "befor shift LOAD_PATH=#{$LOAD_PATH}"
#$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), './'))
#p  "after shift LOAD_PATH=#{$LOAD_PATH}"

require 'sinatra'
require 'app'

run Sinatra::Application
