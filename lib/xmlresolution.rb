
def read_capistrano_revision
  revision_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'REVISION'))
  if File.exists? revision_file
    File.readlines(revision_file)[0].chomp
  else
    'Unknown. Unknowable,  maybe...'
  end
end

module XmlResolution
  REVISION = read_capistrano_revision

  require 'xmlresolution/utils'
  require 'xmlresolution/exceptions'
  require 'xmlresolution/resolvercollection'
  require 'xmlresolution/tarwriter'
  require 'xmlresolution/xmlresolver'
  require 'xmlresolution/logger'
end

