require 'ostruct'

# When we deploy with Capistrano it checks out the code using Git
# into its own branch, and places the git revision hash into the
# 'REVISION' file.  Here we search for that file, and if found, return
# its contents.

def get_capistrano_git_revision
  revision_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'REVISION'))
  File.exists?(revision_file) ? File.readlines(revision_file)[0].chomp : 'Unknown'
end

# When we deploy with Capistrano, it places a newly checked out
# version of the code into a directory created under ../releases/,
# with names such as 20100516175736.  Now this is a nice thing, since
# these directories are backed up in the normal course of events: we'd
# like to include this release number in our service version
# information so we can easily locate the specific version of the
# code, if need be, in the future.
#
# Note that this release information is more specific than a git
# release; it includes configuration information that may not be
# checked in.

def get_capistrano_release
  full_path = File.expand_path(File.join(File.dirname(__FILE__)))
  (full_path =~ %r{/releases/((\d+){14})/}) ? $1 : "Not Available"
end

# Consider a collection of XML documents.  You'd like to gather up all
# of the information necessary to understand them, and gather up that
# information into one tidy bundle.  The XMLResolution classes help
# you to do just that: they will locate and download all of the schemas
# that your documents depend on. (Coming will be DTD and Stylesheet
# support)
#
# 
# We have several classes to effect this:
# 
# - SchemaCatalog  downloads schemas and maintains basic metadata about them (location, namespace, modification times, etc.)
# - PlainXmlDocument and SchemaDocument  are SAX-based XML processors that analyze XML instance documents and schemas, respectively.
# - XmlResolver orchestrates the above components to recursively find all the schema dependencies for an XML instance document.
# - ResolverCollection associates a Collection ID with one or more XML documents and all of the XmlResolver-based information obtained about those documents.
#
# There are a few helper classes as well:
#
# - Logger for logging to Syslog, Standard Error, or a plain file.
# - ResolverUtils for the assorted unsortables.
# - TarWriter for creating tar files on the fly.
# - A hierarchical set of exceptions, rooted at the HttpError class.

module XmlResolution

  REVISION = get_capistrano_git_revision()
  RELEASE  = get_capistrano_release()
  VERSION  = '1.3.4'
  NAME     = 'XMLResolution'

  require 'xmlresolution/exceptions'
  require 'xmlresolution/logger'
  require 'xmlresolution/resolver_collection'
  require 'xmlresolution/schema_catalog'
  require 'xmlresolution/tar_writer'
  require 'xmlresolution/utils'
  require 'xmlresolution/xml_processors'
  require 'xmlresolution/xml_resolver'

  def self.version
    os = OpenStruct.new("rev"    => "#{NAME} Version #{VERSION}, Git Revision #{REVISION}, Capistrano Release #{RELEASE}",
                        "uri"    => "info:fcla/daitss/xmlresolution/#{VERSION}")
    def os.to_s
      self.rev
    end
    os
  end
end


