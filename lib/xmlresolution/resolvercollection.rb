require 'digest/md5'
require 'fileutils'
require 'uri'
require 'builder'
require 'time'
require 'tempfile'
require 'xmlresolution/xmlresolver' #
require 'xmlresolution/tarwriter'   # lets us build tar files on the fly
require 'xmlresolution/utils'
require 'xmlresolution/exceptions'

module XmlResolution

  # Initial Author: Randy Fischer (rf@ufl.edu) for DAITSS
  #
  # This class stores and retrieves information for XmlResolution
  # service.  It maintains a set of collection identifiers supplied by
  # the calling program, and uses the XmlResolution::XmlResolver class
  # to associate documents and the schemas necessary to validate them
  # with a given collection identifier. All of the schemas can be
  # retrieved in a per-collection tarfile.
  #
  # Example usage:
  #
  #   XmlResolution::ResolverCollection.data_path = "/service/path/data"
  #   rc = XmlResolution::ResolverCollection.new('mycollection')
  #
  #   xrez = XmlResolution::XmlResolver.new(xml_text, proxy)
  #   xrez.filename = its_filename
  #   rc.add xrez
  #
  #    ... add some more resolved xml over time ...
  #
  #   rc.tar(STDOUT)

  class ResolverCollection

    # Timeout in seconds for the read_lock and write_lock methods.

    LOCK_TIMEOUT = 10

    # Subdirectory where the collections we create will live:

    COLLECTIONS = 'collections'

    # Subdirectory where all schema information will be placed

    SCHEMAS     = 'schemas'

    @@data_path = nil

    # ResolverCollection.data_path= sets the root directory where all of the data for this class will be
    # stored.  It must be done before using any of the other class methods, except perhaps the
    # ResolverCollection.data_path method.   Objects constructed after this point will keep a local
    # copy

    def self.data_path= path
      raise CollectionInitializationError, "ResolverCollection cannot find the directory '#{path}'."     unless File.directory? path
      raise CollectionInitializationError, "ResolverCollection cannot write to the directory '#{path}'." unless File.writable? path
      @@data_path = path
      [ File.join(path, COLLECTIONS), File.join(path, SCHEMAS) ].each do |p|
        FileUtils.mkdir_p p
        raise "'#{p}' is not writable." unless File.writable? p
      end
    rescue => e
      raise CollectionInitializationError, "ResolverCollection couldn't initialize directory #{path}: '#{e.message}'."
    end

    # Return the current data_path that will be used for created objects.

    def self.data_path
      @@data_path
    end

    # Return a list of all of the active collections stored at this data_path

    def self.collections
      raise CollectionInitializationError, "The ResolverCollection system has not been told what directory to use yet." unless ResolverCollection.data_path
      Dir[File.join(data_path, COLLECTIONS, '*')].map { |path| File.split(path)[-1] }.sort
    end

    # A boolean to determine if a collection_id is active.

    def self.collection_exists? collection_id
      ResolverCollection.collections.include? collection_id
    end

    # A boolean to determine if a string is a valid collection id. It has to fit into the filesystem, so must be a valid single directory name.

    def self.collection_name_ok? collection_id
      not (collection_id =~ /\// or collection_id != URI.escape(collection_id))
    end

    attr_reader :collection_name

    attr_reader :data_path
    attr_reader :schema_path
    attr_reader :collection_path

    def initialize collection_name
      raise CollectionInitializationError, "Must initialize this class with the data_path method before it can be used" unless ResolverCollection.data_path
      raise CollectionNameError, "'#{collection_name}' is a bad name for a collection" unless ResolverCollection.collection_name_ok? collection_name

      @collection_name  = collection_name
      @data_path        = ResolverCollection.data_path
      @schema_path      = File.join(@data_path, SCHEMAS)
      @collection_path  = File.join(@data_path, COLLECTIONS, collection_name)

      FileUtils.mkdir_p  File.join(collection_path)
    end

    private

    # Access the file FILEPATH in a shared manner.  Note that we have
    # two kinds of locks associated with files, read_locks and
    # write_locks.  There may be 0, 1 or many locks active at any
    # time. There may exist many active read_locks at once, but if
    # there is an active write_lock, it is the only lock of any kind.
    # Requests for locks may block for up to LOCK_TIMEOUT seconds,
    # after which a LockError exception is raised.
    #
    # On success, we yield a file desciptor positioned at the
    # beginning of the file and ready to read from.  On return, the
    # file is properly closed.

    def read_lock(filepath)
      open(filepath, 'r') do |fd|
        Timeout.timeout(LOCK_TIMEOUT) { fd.flock(File::LOCK_SH) }
        yield fd
      end
    rescue Timeout::Error => e
      raise LockError, "Timed out waiting #{LOCK_TIMEOUT} seconds for read lock to #{filepath}: #{e.message}"
    end

    # Access the file FILEPATH exclusively. Times out after
    # LOCK_TIMEOUT seconds, raising a LockError exception.  On
    # successfully obtaining a lock we truncate the file, and yield a
    # file descriptor ready for writing.  On return, the file is
    # properly closed.

    def write_lock(filepath)
      open(filepath, 'w') do |fd|
        Timeout.timeout(LOCK_TIMEOUT) { fd.flock(File::LOCK_EX) }
        yield fd
      end
    rescue Timeout::Error => e
      raise LockError, "Timed out waiting #{LOCK_TIMEOUT} seconds for write lock to #{filepath}: #{e.message}"
    end

    # Given an XmlResolution::XmlResolver object XREZ, save the
    # information regarding the file that was analyzed.  That includes the
    # original locations, namespaces, and names of the local copies
    # of all of the schemas that were necessary to fully resolve it.

    def save_document_information xrez
      path = File.expand_path(File.join(collection_path, xrez.digest))
      xrez.local_uri = 'file://' + XmlResolution.hostname  + path

      write_lock (path) do |fd|
        fd.write xrez.dump
      end
    end

    # Given an XmlResolution::XmlResolver object XREZ, save the schema texts we've
    # found.  We use the digest of the text as the filename.

    def save_schema_information xrez
      xrez.schemas.each do |s|
        next unless s.status == :success
        filepath = File.join schema_path, s.digest
        next if File.exists? filepath  and  File.mtime(filepath) == s.last_modified # don't bother rewriting
        write_lock (filepath) do |fd|
          fd.write s.body
          fd.close
          File.utime(File.atime(filepath), s.last_modified, filepath)
        end
      end
    end


# TODO: get manifest data

    def manifest
#      Tempfile.open('manifest') do |tmp|
#        tmp.write(manifest)
#        tmp.close
#        FileUtils.chmod(0644, tmp.path)
#        yield tmp.pathname
#      ensure...deleted
#      end
    end

    # We save schema files by their digests; this returns the full pathname

    def schema_pathname digest
      File.join(schema_path, digest)
    end

    # Loops over all of the collections of saved resolution data for a collection,
    # returning an XmlResolverReloaded object.

    def for_resolutions
      Dir[ File.join(collection_path, '*') ].each do |filepath|
        next if File.directory? filepath
        next unless filepath =~ /[a-z0-9]{32}/
        yield  XmlResolverReloaded.new File.read(filepath)
      end
    end

    # Loops over all of the schemas for all resolutions performed in this collection.
    # The intent is to keep from repeating any schemas, sort the list of schemas
    # by location, and yield each of the schema data-nuggets. Yum!

    def for_schemas
      seen = {}
      for_resolutions do |xrez| 
        xrez.schemas.each do |s| 
          next unless s.status == :success
          seen[s.location] = s
        end
      end
      seen.keys.sort.each { |loc| yield seen[loc] }
    end
    
    public

    # Add the information from the XmlResolver object XREZ to our collection.
    # Note that XREZ is modified; its local_uri slot is updated.

    def add xrez
      save_schema_information xrez
      save_document_information xrez
    end

    # Create a tar file of all the schemas we've found when resolving xml documents sent
    # to this collection. We use the schema location as the filename in the tarfile.

    def tar io
      tarfile = TarWriter.new(io, { :uid => 80, :gid => 80, :username => 'daitss', :groupname => 'daitss' })

#      create_manifest do |path|
#        tarfile.write path, 'manifest.xml'
#      end

      for_schemas do |s|
        tarfile.write schema_pathname(s.digest), File.join(collection_name,  s.location)
      end

      tarfile.close
    end


  end # of class
end # of module