# -*- mode: ruby; -*-

require 'bundler/setup'

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'sinatra'
require './app'

run Sinatra::Application
