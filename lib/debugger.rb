
require 'fileutils'

debug_sentinel = File.expand_path(File.join(File.dirname(__FILE__), '..', 'tmp', 'debug.txt'))

if File.exists?  debug_sentinel
  require 'ruby-debug'
  Debugger.wait_connection = true
  Debugger.start_remote
  FileUtils.rm_f debug_sentinel
end
