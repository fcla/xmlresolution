require 'ostruct'

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
    os = OpenStruct.new("label"   => "Version #{VERSION}, Revision #{REVISION}",
                        "uri"     => "info:fcla/daitss/xmlresolution/#{VERSION}",
                        "note"    => "We'll put additional version information here")
    def os.to_s
      self.label
    end
    os
  end

end


