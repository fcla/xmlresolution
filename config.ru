require 'socket'

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

# We use environment variables here to support two different service
# scenarios. Note that only the top level app.rb pays attention to
# these, and then only in a configure section.
#
# Apache is typically set up along the following lines, where the
# virtual host configuration environment variables will override the
# defaults in this file:
#
# <VirtualHost *:80>
#   ServerName xmlresolution.example.com
#   DocumentRoot ".../xmlresolution/public"
#   SetEnv RESOLVER_PROXY sake.fcla.edu:3128
#   SetEnv LOG_FACILITY LOG_LOCAL2
#   SetEnv DATA_ROOT "/var/xmlresolution"
#   <Directory ".../xmlresolution/public">
#     Order allow,deny
#     Allow from all
#   </Directory>
# </VirtualHost>
#
# We'd also like to be able to run using rackup, where the following
# defaults will kick in:

ENV['LOG_FACILITY']   ||= nil  # default to stderr, may be apache error log, or console depending on how started

ENV['DATA_PATH']      ||= File.expand_path(File.join(File.dirname(__FILE__), 'data'))

ENV['RESOLVER_PROXY'] ||= case Socket.gethostname
                          when /sacred.net/          ; 'satyagraha.sacred.net:3128'
                          when /fcla.edu/, /local/   ; 'sake.fcla.edu:3128'
                          else
                            STDERR.puts "No proxy assigned"
                            nil
                          end

require 'rubygems'
require 'bundler'
Bundler.setup
require 'sinatra'
require 'app'

run Sinatra::Application

