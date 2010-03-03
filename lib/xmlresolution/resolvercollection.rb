require 'fileutils'
require 'uri'
require 'builder'
require 'time'
require 'tempfile'
require 'xmlresolution'

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

    # Last-modified time after which we'll delete collections as being stale.

    TOO_LONG_SINCE_LAST_MODIFIED = 14 * 24 * 60 * 60  # One fortnight

    # Subdirectory where the collections we create will live:

    COLLECTIONS = 'collections'

    # Subdirectory where all schema information will be placed

    SCHEMAS     = 'schemas'

    @@data_path = nil

    # ResolverCollection.data_path= PATH sets the root directory where
    # all of the persistent data for this class will be stored.  It
    # must be done before using any of the other class methods, except
    # perhaps the ResolverCollection.data_path accessor itself.
    # Objects constructed after this point will keep a copy of
    # PATH in an instance variable.

    def self.data_path= path
      raise CollectionInitializationError, "ResolverCollection cannot find the directory '#{path}'."     unless File.directory? path
      raise CollectionInitializationError, "ResolverCollection cannot write to the directory '#{path}'." unless File.writable? path
      @@data_path = path
      [ File.join(path, COLLECTIONS), File.join(path, SCHEMAS) ].each do |p|
        FileUtils.mkdir_p p
        raise CollectionInitializationError, "The path '#{p}' is not a directory." unless File.directory? p
        raise CollectionInitializationError, "The path '#{p}' is not writable."    unless File.writable? p
      end
      age_out_collections File.join(@@data_path, COLLECTIONS)

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

    # A boolean to determine if the collection named by  COLLECTION_ID is active.

    def self.collection_exists? collection_id
      ResolverCollection.collections.include? collection_id
    end

    # A boolean to determine if the string COLLECTION_ID is a valid collection id. It has to fit into the filesystem, so must be a valid single directory name.

    def self.collection_name_ok? collection_id
      not (collection_id =~ /\// or collection_id != URI.escape(collection_id))
    end

    # The name of the collection.

    attr_reader :collection_name

    # The filesystem path where our data is stored.

    attr_reader :data_path

    # The filesystem path where retrieved schemas are are stored.

    attr_reader :schema_path

    # The filesystem path were data about files submitted to this collection are stored.

    attr_reader :collection_path

     # A collection is instantiated by its name, the string COLLECTION_NAME.  The string must be usable as a single filesystem path component.
    # New collections are created via this method; existing collections are retrieved as well.

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

    # Delete a collection if hasn't been updated in a while.

    def self.age_out_collections directory
      Dir["#{directory}/*"].each do |dir|
        next unless  File.directory? dir
        next unless  collection_name_ok? File.split(dir)[-1]
        if (Time.now - File::stat(dir).mtime) > TOO_LONG_SINCE_LAST_MODIFIED
          FileUtils.rm_rf dir
        end
      end
    end


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
      path = File.join(collection_path, xrez.digest)
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
        filepath = cached_schema_pathname(s.digest)
        next if File.exists? filepath  and  File.mtime(filepath) == s.last_modified # don't bother rewriting
        write_lock (filepath) do |fd|
          fd.write s.body
          fd.close
          File.utime(File.atime(filepath), s.last_modified, filepath)
        end
      end
    end

    # We save schema files by naming them after the md5 digest of
    # their contents; this returns the full pathname.

    def cached_schema_pathname digest
      File.join(schema_path, digest)
    end

    # Loops over all of the collections of saved resolution data for a collection,
    # yielding each XmlResolverReloaded object in turn.

    def for_resolutions
      Dir[ File.join(collection_path, '*') ].each do |filepath|
        next if File.directory? filepath
        next unless File.split(filepath)[-1] =~ /^[a-z0-9]{32}$/
        read_lock(filepath) do
          yield  XmlResolverReloaded.new File.read(filepath)
        end
      end
    end

    # Loops over all of the schemas for all resolutions performed in this collection.
    # The intent is to keep from repeating any schemas, sort the list of schemas
    # by location, and yield each of the schema data-nuggets. Yum!

    def for_schemas
      schema_info = {}
      for_resolutions do |xrez|
        xrez.schemas.each do |s|
          next unless s.status == :success
          schema_info[s.location] = s
        end
      end
      schema_info.keys.sort.each { |location| yield schema_info[location] }
    end

    public

    # Return a time object for the last modified time of the collection

    def last_modified
      File::stat(collection_path).mtime
    end

    # Sinatra's last_modified function will check respond_to? :httpdate.

    alias httpdate last_modified

    # manifest produces an xml report on the current state of our collection. When we produce a
    # tar file, a manifest.xml file is included.  This method yields a path to a newly created
    # manifest.xml file.

    def manifest
      $KCODE =~ /UTF8/ or raise ResolverError, "When creating manifest for #{collection_name}, ruby $KCODE was '#{$KCODE}', but it must be 'UTF-8'"

      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.instruct!(:xml, :encoding => 'UTF-8')
      xml.resolutions(:collection => collection_name) {
        for_resolutions do |xrez|
          xml.resolution(:name => xrez.filename, :id => xrez.local_uri, :md5 => xrez.digest, :time => xrez.datetime.xmlschema) {
            xrez.schemas.each do |s|
              next unless s.status == :success
              xml.schema(:status => 'success', :location => s.location, :namespace => s.namespace, :md5 => s.digest, :last_modified => s.last_modified.xmlschema )
            end
            xrez.schemas.each do |s|
              next if s.status == :success
              xml.schema(:status => 'failure', :location => s.location, :namespace => s.namespace, :message => s.error_message)
            end
            xrez.unresolved_namespaces.each do |ns|
              xml.schema(:status => 'unresolved', :namespace => ns)
            end
          }
        end
      }

      Tempfile.open("manifest-#{collection_name}") do |tmp|
        tmp.write(xml.target!)
        tmp.close
        FileUtils.chmod(0644, tmp.path)
        yield tmp.path
        tmp.unlink
      end
    end

    # Add the information from the XmlResolver object XREZ to our collection.
    # Note that XREZ is modified: its local_uri slot is updated to the file uri
    # where it is saved.

    def add xrez
      save_schema_information xrez
      save_document_information xrez
    end

    # Create a tar file of all the schemas we've found when resolving xml documents sent
    # to this collection. We use the schema location as the filename in the tarfile.

    def tar io
      tarfile = TarWriter.new(io, { :uid => 80, :gid => 80, :username => 'daitss', :groupname => 'daitss' })

      manifest do |manpath|
        tarfile.write  manpath, File.join(collection_name, 'manifest.xml')
      end

      for_schemas do |schema_info|
        filepath = cached_schema_pathname(schema_info.digest)
        read_lock(filepath) do
          tarfile.write filepath, File.join(collection_name,  schema_info.location)
        end
      end
      
      tarfile.close
    end

  end # of class
end # of module
