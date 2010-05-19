require 'ostruct'

# TODO: git revision might not be helpful enough since capistrano
# checks out into it's own branch, it would be hard to pick this out
# from a backup tape.  Maybe better to use would be the capistrano
# release in the link tree, e.g. "20100517050854".

def read_capistrano_git_revision
  revision_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'REVISION'))
  File.exists?(revision_file) ? File.readlines(revision_file)[0].chomp : 'Unknown'
end

def get_capistrano_release
  full_path = File.expand_path(File.join(File.dirname(__FILE__)))
  (full_path =~ %r{/releases/(\d+)/}) ? $1 : "Not Available"
end


module XmlResolution
  REVISION = read_capistrano_git_revision
  RELEASE  = get_capistrano_release
  VERSION  = '1.0.0'

  require 'xmlresolution/exceptions'
  require 'xmlresolution/logger'
  require 'xmlresolution/resolver_collection'
  require 'xmlresolution/schema_catalog'
  require 'xmlresolution/tar_writer'
  require 'xmlresolution/utils'
  require 'xmlresolution/xml_processors'
  require 'xmlresolution/xml_resolver'

  def self.version
    os = OpenStruct.new("rev"    => "Version #{VERSION}, Git Revision #{REVISION}, Capistrano Release #{RELEASE}.",
                        "uri"    => "info:fcla/daitss/xmlresolution/#{VERSION}")
    def os.to_s
      "XML Resolution Service #{self.rev}"
    end
    os
  end
end


