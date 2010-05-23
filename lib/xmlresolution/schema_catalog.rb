require 'digest/md5'
require 'net/http'
require 'time'
require 'uri'
require 'xmlresolution/exceptions'
require 'xmlresolution/utils'

module XmlResolution

  # Build up a catalog of schemas from a hash of { Location-URLs => Namespace-URIs }, downloading
  # the schemas. Only HTTP-schemed Location-URLs are supported.  SchemaCatalog does not, by itself, 
  # analyze schemas for additional schemas to download - see our Nokogiri::XML::SAX::Document subclasses
  # PlainXmlDocument and SchemaDocument for that functionality.
  #
  # SchemaCatalog builds a dictionary of interesting information about schemas.  These are accessed with the
  # SchemaCatalog#schemas iterator.  Each record yielded has the following methods:
  #
  # location::             the location of the schema, an HTTP-schemed URL.
  # namespace::            the namespace associated with this schema.
  # last_modified::        on a successful retrieval, this is the last-modified time of the schema (a Time object). If last-modified wasn't available, this is the current datetime.
  # digest::               on a successful retrieval, the MD5 digest of the retrieved text of the schema.
  # localpath::            on a successful retrieval, the filename of the locally-stored copy of the schema.
  # retrieval_status::     the outcome of retrieving the schema: one of :success, :failure, or :redirect.
  # error_message::        if retrieval_status is :failure, this will be the associated error message. Usually a Net::HTTP exception, it could also represent a run-time exception.
  # redirected_location::  if retrieval_status is :redirect, this will be the initial Location URL; the location slot contains the address of the retrieved schema text.

  class SchemaCatalog

    # Be sure to keep the following more or less in sync with the Struct::SchemaReloaded used in the XmlResolverReloaded class;
    # it is the data structure that we maintain in the SchemaCatalog.

    Struct.new("Schema", :location, :namespace, :last_modified, :digest, :localpath, :retrieval_status, :error_message, :redirected_location)

    # As we process schemas, we record that we've seen them

    @processed_locations = nil

    # If a proxy has been given, @proxy_addr is its address, either as a DNS name or IP Address,.

    @proxy_addr = nil

    # If a proxy has been given, @proxy_port is its port, a fixnum. It defaults to 3128 when only the proxy address is supplied.

    @proxy_port = nil

    # @data_root is where we cache the downloaded schema texts.

    @data_root = nil

    # @schema_dictionary is an array of structs that describe schemas.  See 
    # documentation above for the meaning of the slots:
    #
    # When we merge new namespace_locations into the SchemaCatalog, we
    # are careful to add them to the end of the @schema_dictionary
    # array; that way we can extend the list of namespace_locations even
    # as we iterate over them.  See the #merge and #schemas methods for
    # details.

    @schema_dictionary = nil

    # SchemaCatalog.new(NAMESPACE_LOCATIONS, DATA_STORAGE_PATH, [ PROXY ])
    #
    # Creates a catalog of schemas.  DATA_STORAGE_PATH provides a path
    # to where downloaded schemas can be saved. PROXY, if supplied, is
    # the address and port of a caching web proxy,
    # e.g. squid.example.com:3128.
    #
    # NAMESPACE_LOCATIONS is a hash of Location-URL/Namespace-URN key/value pairs
    # of schemas that will downloaded; the SchemaCatalog provides a convenient
    # data structure to recursively analyze a set of schemas:
    #
    #   catalog = SchemaCatalog.new(namespace_locations, '/tmp/')
    #
    #   catalog.schemas do |schema_record|
    #     more_namespace_locations =  analyze_schema(schema_record.localpath)
    #     catalog.merge(more_namespace_locations)
    #    end
    #
    # (What's happening above is that the iterator catalog.schemas is being augmented
    # via the catalog.merge method, allowing us to recursively search the schemas.)

    def initialize namespace_locations, data_storage_path = '/tmp/', proxy = nil
      if proxy
        @proxy_addr, @proxy_port = proxy.split(':', 2)
        @proxy_port  = @proxy_port.nil? ? 3128 : @proxy_port.to_i
      end

      @processed_locations = {}
      @data_root = data_storage_path.gsub(%r{/+$}, '')

      ResolverUtils.check_directory "The schema storage directory", @data_root

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
    #   catalog = SchemaCatalog.new(namespace_locations, 'tmp')
    #   catalog.schemas do |rec|
    #     next if rec.retrieval_status != :success
    #     additional_namespace_locations = my_application(rec.location, File.read(rec.pathname))
    #     catalog.merge additional_namespace_locations
    #   end

    def schemas
      if block_given?
        @schema_dictionary.each { |record| yield record }   # need to preserve order here: the array acts as a queue in this role.
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
    # Merge lets us add new schema records to the SchemaCatalog, but
    # we take care not to overwrite existing records that have already
    # been processed.

    def merge namespace_locations

      # For each location in NAMESPACE_LOCATIONS hash, check to see if
      # they aren't yet in our schema_dictionary, go fetch them.  If we
      # get a schema record that has a different location than we asked
      # for, one or more redirects occured: mark it as such.

      namespace_locations.each do |location, namespace|

        next if @processed_locations[location]

        schema_record = get_schema_record(location, namespace)

        @schema_dictionary.push schema_record
        @processed_locations[schema_record.location] = true

        if schema_record.location != location   # then one or more redirects

          original = Struct::Schema.new(location, schema_record.namespace)
          original.retrieval_status    = :redirect
          original.redirected_location = schema_record.location

          @schema_dictionary.push  original
          @processed_locations[original.location] = true
        end
      end
    end

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

      ### TODO: write a log in the schemas directory with time, location, and digest

      return record

    rescue => e
      record.retrieval_status = :failure
      record.error_message    = e.message   # It is the calling program's responsibility to log this error
      return record                         # when appropriate; use the schemas method for iterating over
    end                                     # all schema records in the catalog, check retrieval_status
                                            # for :success, :redirect or :failure.

    # fetch LOCATION [ REDIRECT-LIMIT ]
    #
    # Given an HTTP location LOCATION, fetch and return the response.
    # Permit up to five redirections by default.

    def fetch location, limit = 5
      uri = URI.parse location

      # TODO: Branch to handle file URLs here, maybe.
      # TODO: create an XML document that uses an FTP scheme, to check this error occurs.

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
end # of XmlResolution module
