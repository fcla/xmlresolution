
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

  class Rc

    # Timeout in seconds for the read_lock and write_lock methods.

    LOCK_TIMEOUT = 10
    
    # Subdirectory where the collections we create will live:

    COLLECTIONS = 'collections'

    # Subdirectory where all schema information will be placed

    SCHEMAS     = 'schemas'

    @@data_path = nil

    def self.data_path= path
      raise CollectionInitializationError, "ResolverCollections cannot find the directory '#{path}'."     unless File.directory? path
      raise CollectionInitializationError, "ResolverCollections cannot write to the directory '#{path}'." unless File.writable? path
      @@data_path = path
      [ File.join(path, COLLECTIONS), File.join(path, SCHEMAS) ].each do |p|
        FileUtils.mkdir_p p
        raise "'#{p}' is not writable." unless File.writable? p
      end
    rescue => e
      raise CollectionInitializationError, "ResolverCollections couldn't initialize directory #{path}: '#{e.message}'."
    end
    
    def self.data_path 
      @@data_path
    end

    def self.collections
      raise CollectionInitializationError, "The ResolverCollections system has not been told what directory to use yet." unless Rc.data_path     
      Dir[File.join(data_path, COLLECTIONS, '*')].map { |path| File.split(path)[-1] }.sort
    end
        
    attr_reader :collection_name
    attr_reader :data_path, :schema_path, :collection_path

    def initialize collection_name
      raise CollectionInitializationError, "Must initialize this class with the data_path method before it can be used" unless Rc.data_path  

      @collection_name  = collection_name
      @data_path        = Rc.data_path
      @schema_path      = File.join(@data_path, SCHEMAS)
      @collection_path  = File.join(@data_path, COLLECTIONS, collection_name)

      FileUtils.mkdir_p  File.join(collection_path)
    end

    private

    # Access the file FILEPATH exclusively. Times out after LOCK_TIMEOUT seconds.  Truncates
    # the file, and yields a file descriptor ready to write to.

    def write_lock(filepath)
      open(filepath, 'w') do |fd|
        Timeout.timeout(LOCK_TIMEOUT) { fd.flock(File::LOCK_EX) }
        yield fd
      end
    rescue Timeout::Error => e
      raise LockError, "Timed out waiting #{LOCK_TIMEOUT} seconds for write lock to #{filepath}: #{e.message}"
    end

    # Access the file FILEPATH in a shared manner: many read_locks can be active, but only
    # one write_lock.  Timeouts after LOCK_TIMEOUT seconds, and yields a file desciptor ready
    # to read from.


    def self.read_lock(filepath)
      open(filepath, 'r') do |fd|
        Timeout.timeout(LOCK_TIMEOUT) { fd.flock(File::LOCK_SH) }
        yield fd
      end
    rescue Timeout::Error => e
      raise LockError, "Timed out waiting #{LOCK_TIMEOUT} seconds for read lock to #{filepath}: #{e.message}"
    end

    public


    # Given an XmlResolution::XmlResolver object XREZ, save the
    # information about the file that was resolved.  That includes the
    # locations, namespaces, and the local filenames of schemas that
    # are necessary to resolve it.  We always construct the filenames
    # from the digest of the schema text.  We'll save the actual
    # schema text elsewhere.

    def save_document_information xrez

      # # If XmlResolver throws an error, we let the top level figure out if it's a 400 or 500 class error.
      #
      # given xml_text, filename, and a caching proxy:
      # 
      # xrez = XmlResolution::XmlResolver.new(xml_text, caching_proxy)
      # xrez.filename = filename

      writelock (File.join collections, xrez.digest) do |fd|
        fd.write xrez.dump
      end
    end

    # Given an XmlResolution::XmlResolver object XREZ, save all of the schema data we 
    # We never save the file text itself.

    def save_schema_information xrez

      xrez.schemas do |s|
        next unless s.status == :success
        filepath = File.join schemas, s.digest
        next if File.exists? filepath  and  File.mtime(filepath) == s.last_modified
        writelock (filepath) do |fd|
          fd.write s.body
          fd.close
          File.utime(File.atime(filepath), s.last_modified, filepath)
        end
      end

    end

  end # of class
end # of module


