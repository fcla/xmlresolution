require 'digest/md5'
require 'net/http'
require 'time'
require 'uri'
require 'xmlresolution/exceptions'  # 
require 'xmlresolution/utils'       # ResolverUtils.*

# Build up a catalog of schemas from a hash of { Location-URLs => Namespace-URIs }, downloading
# the schemas. Only HTTP-schemed Location-URLs are supported.  A SchemaCatalog is associated for
# exactly one XML document.

class SchemaCatalog

  # If a proxy has been given, @proxy_addr is its address, either as a DNS name or IP Address,.

  @proxy_addr = nil

  # If a proxy has been given, @proxy_port is its port, a fixnum. It defaults to 3128 when only the proxy address is supplied.

  @proxy_port = nil

  # @data_root is where we cache the downloaded schema texts.

  @data_root = nil

  # @schema_dictionary is an array of structs that describe schemas.  The structs have the following slot names and meanings:
  # 
  #  * location		    the location of the schema, an HTTP-schemed URL.
  #  * namespace	    the namespace associated with this schema.
  #  * last_modified 	    on a successful retrieval, this is the last-modified time of the schema (a Time object). If last-modified wasn't available, this is the current datetime.
  #  * digest		    on a successful retrieval, the MD5 digest of the retrieved text of the schema.
  #  * localpath            on a successful retrieval, the filename of the locally-stored copy of the schema.
  #  * retrieval_status     the outcome of retrieving the schema: one of :success, :failure, or :redirect.
  #  * error_message        if retrieval_status is :failure, this will be the associated error message. Usually a Net::HTTP exception, it could also represent a run-time exception.
  #  * redirected_location  if retrieval_status is :redirect, this will be the original Location URL.
  #
  # When we merge new namespace_locations into the SchemaCatalog, we
  # are careful to add them to the end of the @schema_dictionary
  # array; that way we can extend the list of namespace_locations even
  # as we iterate over them.  See the #merge and #schemas methods for
  # details.

  @schema_dictionary = nil

  def initialize namespace_locations, data_storage_path = '/tmp/', proxy = nil

    if proxy
      @proxy_addr, @proxy_port = proxy.split(':', 2)
      @proxy_port  = @proxy_port.nil? ? 3128 : @proxy_port.to_i
    end

    @data_root = data_storage_path.gsub(%r{/+$}, '') 

    ResolverUtils.check_directory "The schema storage directory", @data_root

    # Be sure to keep the following more or less in sync with the Struct::SchemaReloaded used in the XmlResolverReloaded class.

    Struct.new("Schema", :location, :namespace, :last_modified, :digest, :localpath, :retrieval_status, :error_message, :redirected_location)
    
    @schema_dictionary = []
    merge namespace_locations
  end

  # schemas
  #
  # Our main iterator - yields the next schema record when given a
  # block, otherwise a complete list of the schema records,
  # alphabetically sorted by location.
  #
  # It is expected that the catalog will be expanded through the merge
  # method while being iterated over, as in the following example:
  #
  # catalog = SchemaCatalog.new(namespace_locations)
  # catalog.schemas do |rec|
  #   additional_locations = my_application(rec.location, File.read(rec.pathname))
  #   catalog.merge additional_locations
  # end

  def schemas
    if block_given?
      @schema_dictionary.each { |record| yield record }
    else
      @schema_dictionary.sort{ |a,b| a.location.downcase <=> b.location.downcase }
    end
  end
  
  # merge NAMESPACE_LOCATIONS
  #
  # NAMESPACE_LOCATIONS is a hash of location-URL/namespace-URN
  # key/value pairs, the same data structure passed to us in the
  # constructor.
  #
  # Merge lets us add new schema records to the SchemaCatalog, but we
  # take care not to overwrite existing records that have been processed.
  # Note that this method will silently ignore new records in the case
  # where we have identical locations for different namespaces ("can't
  # happen").  

  def merge namespace_locations

    # Make a stop list for everything we already have:

    seen = Hash.new
    @schema_dictionary.each { |elt| seen[elt.location] = true }

    # For each location in NAMESPACE_LOCATIONS hash, check to see if
    # they aren't yet in our schema_dictionary, go fetch them.  If we
    # get a schema record that has a different location than we asked
    # for, one or more redirects occured: mark it as such.

    namespace_locations.each do |location, namespace|
      next if seen[location]

      schema_record = get_schema_record(location, namespace)
      @schema_dictionary.push schema_record

      if schema_record.location != location   # then one or more redirects

        original = Struct::Schema.new(location, schema_record.namespace)
        original.retrieval_status    = :redirect
        original.redirected_location = schema_record.location

        @schema_dictionary.push  original
      end      
    end
  end

  # unresolved_namespaces
  #
  # Return those namespaces known to have been used, but that have
  # not (yet) had a location found, and the schema downloaded, for it.
  #
  
  private

  # get_schema_record LOCATION, NAMESPACE
  #
  # Retrieve the schema from LOCATION, if possible.  Save the text of
  # the schema to a directory.  Returns a record listing the location,
  # namespace, text location, digest and last-modification time; See
  # the detailed description of the @schema_dictionary instance
  # variable for the details.

  def get_schema_record location, namespace

    record = Struct::Schema.new(location, namespace)

    response, actual_location = fetch location

    record.digest           = Digest::MD5.hexdigest(response.body)
    record.last_modified    = response['Last-Modified'] ? Time.parse(response['Last-Modified']) : Time.now
    record.localpath        = File.join(@data_root, record.digest)
    record.location         = actual_location
    record.retrieval_status = :success

    if not file_recorded?(record.localpath, record.last_modified, record.digest)
      ResolverUtils.write_lock(record.localpath) do |fd|
        fd.write response.body
        fd.close
        File.utime(File.atime(record.localpath), record.last_modified, record.localpath)
      end
    end

    return record

  rescue => e
    record.retrieval_status = :failure
    record.error_message    = e.message   # It is the calling program's responsibility to log this error          
    return record                         # when appropriate; use the schemas method for iterating over
  end                                     # all schema records in the catalog (status will be one of
  					  # :success, :redirect or :failure).

  # fetch LOCATION [ REDIRECT-LIMIT ]
  #
  # Given an HTTP location LOCATION, fetch and return the response.
  # Permit up to five redirections by default.

  def fetch location, limit = 5
    uri = URI.parse location

    # TODO: Branch to handle file URLs here, maybe.
    # TODO: create an XML document that uses an FTP scheme, to check this error.

    raise LocationError, "#{uri.scheme} is not a supported protocol - #{location} not retrieved."  unless uri.scheme == 'http'
    raise LocationError, "#{location} can't be retrieved, there were too many redirects."          if limit < 1

    # Note that if proxy_addr & proxy_port are nil,  Net::HTTP::Proxy is equivalent to Net::HTTP

    Net::HTTP::Proxy(@proxy_addr, @proxy_port).start(uri.host, uri.port) do |http|
      response  = http.get(uri.path)
      case response
      when Net::HTTPSuccess     then return [ response, location ] 
      when Net::HTTPRedirection then fetch response['location'], limit - 1
      else
        response.error!
      end
    end
  end # of fetch

  # file_recorded? FILENAME, MTIME, DIGEST
  #
  # A boolean method, return whether FILENAME has the mtime MTIME and MD5 Digest DIGEST. FILENAME
  # does not have to exist, but if it does, it must be readable.

  def file_recorded? filename, mtime, digest
    return false unless File.exists?(filename) 
    ResolverUtils.read_lock(filename) { |fd| (File.mtime(filename) == mtime) and (Digest::MD5.hexdigest(fd.read) == digest) }
  end

end # of class SchemaCatalog
