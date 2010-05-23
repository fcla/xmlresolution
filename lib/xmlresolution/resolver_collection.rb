require 'builder'
require 'fileutils'
require 'tempfile'
require 'time'
require 'uri'
require 'xmlresolution'

module XmlResolution

  # Initial Author: Randy Fischer (rf@ufl.edu) for DAITSS
  #
  # This class stores and retrieves information for the XmlResolution
  # service.  It maintains a set of collection identifiers supplied by
  # the client, and uses the XmlResolution::XmlResolver class to
  # associate documents and the schemas necessary to validate them
  # with this collection identifier. All of a set of documents
  # resolved schemas can be retrieved in a per-collection tarfile.
  #
  # Example usage: write a mainfest file for the collection 'foo'; the
  # collections are stored under '/var/data'
  #
  #  collection = ResovlerCollection.new '/var/data', 'foo'
  #  File.open("foo.xml", "w")  { |f| f.write collection.manifest }
  #
  # Example usage: write tar files for all the collections we have,
  # stored under '/var/data'
  #
  #  root = '/var/data'
  #  ResolverCollection.collections(root).each do |collection_name|
  #    collection = ResolverCollection.new root, collection_name
  #    File.open("#{collection_name}.tar", "w") do |f| 
  #      collection.tar do |io|
  #        f.write io.read
  #      end
  #    end
  #  end
  #  

  class ResolverCollection

    # Last-modified time after which we'll delete collections as being stale.

    TOO_LONG_SINCE_LAST_MODIFIED = 14 * 24 * 60 * 60  # One fortnight

    # The client-supplied id for grouping a collection of XML documents.

    attr_reader :collection_name

    # data_path is the topmost path we need to concern ourselves with,
    # where schemas and collections all live. Say it is named
    # "...data_root"; then the heirarchy looks like this:
    #
    #   ...data_root/collections
    #   ...
    #   ...data_root/collections/E20010101_CEEBEE                                    # a collection
    #   ...data_root/collections/E20010101_CEEBEE/74e5729189a158f105eb113be42a123a   # a document record
    #   ...data_root/collections/E20010101_CEEBEE/d25504bfb5986db329e02b2d447cc4e7
    #   ...
    #   ...data_root/collections/E20010101_DEADER                                    # another collection
    #   ...data_root/collections/E20010101_DEADER/e6720c9ea7e7f2a70d8dd20b1af84020   # its document records
    #   ...data_root/collections/E20010101_DEADER/e68ac0fe9f938ccf339afe4a76bfd26b
    #   ...data_root/collections/E20010101_DEADER/ee209b5a6c70b495a130cad8d20eb779
    #   ...
    #   ...data_root/schemas                                                         # where the schemas live
    #   ...data_root/schemas/005aead63fe2e6a13152ecad7e702a21                        # a dowmloaded schema
    #   ...data_root/schemas/02592d8f2bb29d7f4f8e413fdb22c3e0
    #   ...data_root/schemas/0bfe4d177184c3e01c674951481be6af
    #   ...data_root/schemas/15fa7e3aedef6801c565bfbf621fdc5b
    #   ...data_root/schemas/1ad7d28cc5587a80cfde5e47b3265e39
    #   ...
    #       ...lots more schemas...

    attr_reader :data_path

    # The top-level path where we store collections information; collection_name will be
    # a subdirectory of this.

    attr_reader :collections_path

    # The top-level path where we store downloaded schemas.

    attr_reader :schemas_path

    # ResolverCollection.collections pathname
    #
    # This class method returns a list of collection names currently
    # present on the system. The top-level collections directory
    # exists as a subdirectory under PATHNAME, a string. This is
    # equivalent to the data_path used by the constructor.

    def ResolverCollection.collections pathname
      raise XmlResolution::ConfigurationError, "The root data path has not been set" unless pathname
      collections_pathname = File.join(pathname, 'collections')
      ResolverUtils.check_directory "The directory for storing the collections",  collections_pathname
      ResolverCollection.age_out_collections collections_pathname
      Dir[File.join(collections_pathname, '*')].map { |path| File.split(path)[-1] }.sort
    end

    # ResolverCollection.new PATHNAME, COLLECTION_NAME
    #
    # Create a new ResolverCollection object associated with the
    # persistent object store (files) at PATHNAME, known by
    # COLLECTION_NAME (both strings).
    #
    # It will, as a side effect, create a directory COLLECTION_NAME
    # under PATHNAME if it doesn't alreday exists and if
    # COLLECTION_NAME is well-formed.  If you don't want that, you'd
    # want to do a check in your app along the lines of:
    #
    # if ResolverCollection.collections(data_root).include? Users_Collection_Name
    #    collection = ResolverCollection.new(data_root, Users_Collection_Name) 
    #    ...
    # else
    #    Boom!
    # end

    def initialize pathname, collection_name

      @collection_name  = collection_name
      @data_path        = pathname

      if not ResolverUtils.collection_name_ok? collection_name
        raise XmlResolution::BadCollectionID, "Bad collection name '#{collection_name}' - it has to be a simple string with no spaces or special characters"
      end

      @schemas_path       = File.join(data_path, 'schemas')
      @collections_path   = File.join(data_path, 'collections')

      ResolverUtils.check_directory "The directory for storing schemas",            @schemas_path
      ResolverUtils.check_directory "The directory for storing XML document data",  @collections_path

      FileUtils.mkdir_p  File.join(collection_documents_path)  
    end

    # manifest [ COLLECTION_RESOLUTIONS ]
    #
    # Create and return the XML manifest document for this collection.
    # If COLLECTION_RESOLTIONS, an array of XmlResolver objects
    # associated with this collection, is provided, use that.
    # Otherwise, create it ourselves. (We do this because manifest is
    # used within the tar method, which already has created the array
    # of XmlResolver objects for its own use).
    # 
    #  Annotated portions of an example manifest document:
    #
    #  <?xml version="1.0" encoding="UTF-8"?>
    #
    #  <resolutions collection="E20100524_AAACAB">
    #
    #   A 'resolution' refers to one document, characterized as follows:
    #
    #    <resolution time="2010-05-15T01:20:23-04:00" 
    #                 md5="74e5729189a158f105eb113be42a123a" 
    #                name="file://127.0.0.1/UF00028295_00729.xml">
    #
    #   The successfully retrieved schemas:
    #
    #      <schema last_modified="2010-04-21T11:44:40-04:00"/      
    #                     status="success" 
    #                        md5="15fa7e3aedef6801c565bfbf621fdc5b" 
    #                  namespace="http://www.fcla.edu/dls/md/daitss/"
    #                   location="http://www.fcla.edu/dls/md/daitss/daitss.xsd">
    #
    #      <schema last_modified="2010-04-21T11:44:40-04:00"/
    #                     status="success" 
    #                        md5="1e07ae0bf17cb5ef171f087f2155f038" 
    #                   location="http://www.fcla.edu/dls/md/daitss/daitssAccount.xsd" 
    #                  namespace="http://www.fcla.edu/dls/md/daitss/">
    #
    #      <schema last_modified="2010-04-21T11:44:40-04:00"/
    #                     status="success" 
    #                        md5="e3b452af1c0b4c9c3b696cf1bf3fdb19" 
    #                   location="http://www.fcla.edu/dls/md/daitss/daitssAccountProject.xsd" 
    #                  namespace="http://www.fcla.edu/dls/md/daitss/">
    #
    #      <schema last_modified="2010-04-21T11:44:40-04:00"/
    #                     status="success" 
    #                        md5="56ac338a8916c7099b8c5563721db9bd" 
    #                   location="http://www.fcla.edu/dls/md/daitss/daitssActionPlan.xsd" 
    #                  namespace="http://www.fcla.edu/dls/md/daitss/">
    #
    #  Redirected schemas:
    #
    #      <schema      status="redirect" 
    #                 location="http://www.loc.gov/mods/v3/mods-3-3.xsd" 
    #                namespace="http://www.loc.gov/mods/v3" 
    #                   actual="http://www.loc.gov/standards/mods/v3/mods-3-3.xsd"/>
    #
    #      <schema      status="redirect" 
    #                 location="http://www.loc.gov/mods/v3/mods-3-3.xsd" 
    #                namespace="http://www.loc.gov/mods/v3" 
    #                  actual="http://www.loc.gov/standards/mods/v3/mods-3-3.xsd"/>
    #
    #  Unresolved:
    #
    #      <schema     status="unresolved" 
    #               namespace="http://www.w3.org/1999/xhtml"/>
    #
    #      <schema    status="unresolved" 
    #               namespace="http://www.w3.org/2001/XMLSchema-hasFacetAndProperty"/>
    #
    #  Error container if errors were reported for the instance document:
    #
    #      <errors>
    #        <error>StartTag: invalid element name</error>
    #      </errors>
    #
    #    </resolution>
    #
    #  More resolutions:
    #    
    #    <resolution time="2010-05-14T00:46:56-04:00" 
    #                 md5="d25504bfb5986db329e02b2d447cc4e7" 
    #                 name="file://127.0.0.1/example.xml">
    #      ....
    #
    #    </resolution>
    # </resolutions>
    
    def manifest collection_resolutions = nil
      collection_resolutions ||= resolutions()  

      $KCODE == 'UTF8' or raise XmlResolution::ConfigurationError, "Ruby $KCODE == #{$KCODE}, but it must be UTF8"
      
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.instruct!(:xml, :encoding => 'UTF-8')
      xml.resolutions(:collection => collection_name) {
        collection_resolutions.each do |res|
          xml.resolution(:name => res.document_uri, :md5 => res.document_identifier, :time => res.resolution_time.iso8601) {       
            res.schema_dictionary.each do |s|
              next unless s.retrieval_status == :success
              xml.schema(:status => 'success', :location => s.location, :namespace => s.namespace, :md5 => s.digest, :last_modified => s.last_modified.iso8601)
            end
            res.schema_dictionary.each do |s|
              next unless s.retrieval_status == :failure
              xml.schema(:status => 'failure', :location => s.location, :namespace => s.namespace, :message => s.error_message)
            end
            res.schema_dictionary.each do |s|
              next unless s.retrieval_status == :redirect
              xml.schema(:status => 'redirect', :location => s.location, :namespace => s.namespace, :actual => s.redirected_location)
            end
            res.unresolved_namespaces.each { |ns| xml.schema(:status => 'unresolved', :namespace => ns) }
            if not res.errors.empty?
              xml.errors {
                res.errors.each { |mess| xml.error(mess) }
              }
            end
          }
        end
      }
      xml.target!
    end
    
    # tar
    #
    # Create a tar file of all the schemas we've found when resolving
    # xml documents sent to this collection. We use the schema
    # location as the filename in the tarfile.  We include a manifest
    # of the results of performing the resolutions; each document is
    # listed in a section of the manifest, with references to schemas
    # included in the tarfile.  If the name of the collection is
    # 'FOO', then the contents of the tarfile for the collection has
    # the following layout:
    #
    #  FOO/manifest.xml
    #  FOO/http://www.fcla.edu/dls/md/daitss/daitss.xsd
    #  FOO/http://www.fcla.edu/dls/md/daitss/daitssAccount.xsd
    #  FOO/http://www.fcla.edu/dls/md/daitss/daitssAccountProject.xsd
    #  FOO/...more schemas...
    #
    # We yield an open tempfile containg the contents of the tarfile.
    # The tempfile is deleted after exiting the tar block.
    #
    
    def tar
      io = Tempfile.new 'XmlResolution-TarFile-'
      rs  = resolutions()

      tarwriter = XmlResolution::TarWriter.new(io, { :uid => 80, :gid => 80, :username => 'daitss', :groupname => 'daitss' })
      manifest_file(rs) { |path| tarwriter.write path, File.join(collection_name, 'manifest.xml') }
      schemas(rs) { |localpath, url|  tarwriter.write localpath, File.join(collection_name, url) }

      tarwriter.close  # closes io as side effect

      io.open.rewind
      yield io
    ensure
      io.close
      io.unlink
    end

    # resolutions
    #
    # Return an array of XmlResolver objects, one associated with each
    # of the documents that have been successfully submitted to this
    # collection.

    def resolutions
      collection_documents.map { |id|  XmlResolverReloaded.new(data_path, collection_name, id) }
    end

    private

    # manifest_file COLLECTION_RESOLUTIONS
    #
    # Save the manifest report (an XML document) to a temporary file, and yield
    # that files pathname. 

    def manifest_file collection_resolutions
      Tempfile.open("manifest-#{collection_name}-xml-") do |tmp|
        tmp.write manifest(collection_resolutions)
        tmp.close
        FileUtils.chmod(0644, tmp.path)
        yield tmp.path
        tmp.unlink
      end
    end

    # collection_documents_path
    #
    # The directory where we keep all of our documents for this
    # particular collection.  See the documentation above on data_path
    # for the overall filesystem layout.

    def collection_documents_path
      File.join(collections_path, collection_name)
    end

    # age_out_collections COLLECTIONS_PATHNAME
    #
    # Check all of the collections under COLLECTIONS_PATHNAME,
    # deleting those that haven't been updated in a while.

    def ResolverCollection.age_out_collections  collections_pathname
      Dir["#{collections_pathname}/*"].each do |dir|
        next unless  File.directory? dir
        next unless  ResolverUtils.collection_name_ok? File.split(dir)[-1]
        if (Time.now - File::stat(dir).mtime) > TOO_LONG_SINCE_LAST_MODIFIED
          FileUtils.rm_rf dir
        end
      end
    end

    # collection_documents
    #
    # Retun an array of all of the document identifiers associated
    # with this collection.  The identifier is the MD5 digest of the
    # original document contents; it is used as the filename of simple
    # text file containg information about the original document.  See
    # the documentation for data_path for information on the file
    # layout that includes these files; see the XmlReslolver#dump
    # method for documentation on its contents.

    def collection_documents
      ResolverCollection.age_out_collections collections_path
      ResolverUtils.check_directory "The document directory for #{collection_name}", collection_documents_path
      ids = []
      Dir["#{collection_documents_path}/*"].each do |path|
        next if File.directory? path 
        filename = File.basename(path)
        next unless filename =~ /^[a-f0-9]{32}$/
        ids.push filename
      end
      ids.sort{ |a,b| a.downcase <=> b.downcase }
    end

    # schemas DOCUMENT_RESOLUTIONS
    #
    # Given the array of XmlResolver (or XmlResolverReloaded) objects,
    # DOCUMENT_RESOLUTIONS, trundle through all of the successfully
    # retrieved schemas for this collection.
    #
    # Yields the unique list of the schemas; for each one, yield the
    # path to the local copy we have of them, and their original URLs.
    # Duplicates are weeded out.

    def schemas document_resolutions
      seen = {}      
      resolutions.each do |res|
        res.schema_dictionary.each do |record|
          next unless record.retrieval_status == :success
          next if seen[record.location]
          yield record.localpath, record.location
          seen[record.location] = true
        end
      end
    end

  end # of class
end # of module
