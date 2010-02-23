require 'digest/md5'
require 'libxml'
require 'net/http'
require 'uri'
require 'time'      # brings in parse method, iso8601, xmlschema
require 'ostruct'
require 'builder'
require 'xmlresolution/exceptions'
require 'xmlresolution/utils'

include LibXML

module XmlResolution

  # Initial Author: Randy Fischer (rf@ufl.edu) for DAITSS
  # 
  # This class analyzes an XML document, attempting to recursively
  # retrieve all of the schema documents required to correctly validate
  # it. It will optionally use an HTTP caching proxy such as squid to
  # fetch the schemas.  A list of namespaces that were not able to be
  # resolved can be retrieved using the unresolved_namespaces method.
  #
  # Example usage:
  #
  #   xrez = XmlResolution::XmlResolver.new(File.read("F20060215_AAAAHL.xml"), "satyagraha.sacred.net:3128")
  #   xrez.schemas.each do |rec|
  #     next unless rec.status == :success
  #     puts "#{rec.namespace}  => #{rec.location}\n"
  #   end
  #   puts "\nUnresolved: " + xrez.unresolved_namespaces.join(", ")
  #
  # which might return
  #
  #  http://www.loc.gov/METS/ => http://www.loc.gov/standards/mets/mets.xsd
  #  http://www.fcla.edu/dls/md/daitss/ => http://www.fcla.edu/dls/md/daitss/daitss.xsd
  #  http://www.fcla.edu/dls/md/palmm/ => http://www.fcla.edu/dls/md/palmm.xsd
  #  http://www.fcla.edu/dls/md/techmd/ => http://www.fcla.edu/dls/md/techmd.xsd
  #  http://www.fcla.edu/dls/md/rightsmd/ => http://www.fcla.edu/dls/md/rightsmd.xsd
  #  http://purl.org/dc/elements/1.1/ => http://dublincore.org/schemas/xmls/simpledc20021212.xsd
  #
  #  Unresolved: http://www.w3.org/1999/xlink, http://www.w3.org/2001/XMLSchema-instance
  #
  # Two notes on squid caching proxies: at least by default, redirects
  # are not cached (even 301 "moved permanently") so that there will
  # always be a request to the original host resulting in a redirect
  # that we will handle (though the URL we are directed to will usually
  # be cached) - an example is http://www.loc.gov/mods/v3/mods-3-2.xsd.
  # Secondly, there are common schemas, such as
  # http://dublincore.org/schemas/xmls/simpledc20021212.xsd, that squid
  # cannot cache since there is no Last-Modified, Etag, or
  # caching/expiration information associated with it. These kinds of
  # issues slow us down somewhat.

  class XmlResolver

    # The schemas attribute holds a list of ostructs, where
    # each has accessors defined as so:
    #
    #   * body            => [ string | nil ],         the schema text
    #   * digest          => [ md5-hex-string | nil ]  an md5 checksum of the body text
    #   * error_message   => [ string | nil ]          if status is :failure, an error message
    #   * last_modified   => DateTime                  the modification time of the retrieved schema
    #   * location        => url-string                where we got the schema from
    #   * namespace       => urn-string                its associated namespace
    #   * status          => [ :success | :failure ]

    attr_reader :schemas

    # proxy_address is the address part of the caching proxy server,
    # if one was specified in the constructor, nil otherwise. Either a
    # hostname or an IP address can be used.

    attr_reader :proxy_addr

    # proxy_port is the port of the caching proxy server, if a proxy
    # server was specified in the constructor.  If not explicitly set,
    # it defaults to 3128.

    attr_reader :proxy_port

    # Calling programs may want to decorate this object with the original filename (we get only
    # the xml document text as a string),  we'll save this if we have it.

    attr_accessor :filename

    # Like the filename accessor above, local_uri allows calling programs
    # to save the hostname and the file to which is the file containing
    # information about this xml document; this is mostly to serve as a unique
    # id for people that want to create xml documents based on this
    # object. The intent is to use a filename URI.

    attr_accessor :local_uri

    # Time that we started processing this xml document.

    attr_accessor :datetime

    # We'll want to record the digest fingerprint for the data for the xml document

    attr_reader :digest

    # Create an XML resolver object given an xml docment in the string
    # XML_TEXT. Optionally provide the string CACHING_HTTP_PROXY, naming
    # a caching proxy to use when retrieving schemas or DTDs (format
    # "hostname:port",  port defaults to 3128).

    def initialize xml_text, caching_http_proxy = nil
      @namespaces_found = {}

      @filename = nil
      @proxy_port = @proxy_addr = nil   # possible to have no proxy - then we'll contact locations directly

      if caching_http_proxy
        @proxy_addr, @proxy_port = caching_http_proxy.split(':', 2)
        if @proxy_port.nil?
          @proxy_port = 3128
        else
          @proxy_port = @proxy_port.to_i
        end
      end

      @digest   = Digest::MD5.hexdigest xml_text
      @schemas  = get_schemas xml_text
      @datetime = Time.now
    end



    # Return a list of namespaces that were encountered, but never had a location associated with them.

    def unresolved_namespaces
      @namespaces_found.collect { |namespace, located| namespace if not located }.compact.sort
    end

    # Return a string representation of our analysis of an xml document, along the lines of:
    #
    #  DIGEST md5
    #  DATE_TIME time
    #  SCHEMA md5 modification location namespace
    #  SCHEMA md5 modification location namespace
    #  SCHEMA md5 modification location namespace
    #  SCHEMA md5 modification location namespace
    #   ....
    #  UNRESOLVED_NAMESPACES namespace namespace namespace ....
    #  BROKEN_SCHEMA location namespace error_message
    #
    # optionally, we may have:
    #
    #  FILE_NAME externally-supplied-filename
    #  LOCAL_URI file-uri
    #
    # Each 'phrase' is URL-escaped, so embeded whitespace won't cause parsing problems.

    def dump
      str = ''

      str += XmlResolution.escape("FILE_NAME", filename)         + "\n" if filename
      str += XmlResolution.escape("LOCAL_URI", local_uri)        + "\n" if local_uri

      str += XmlResolution.escape("DATE_TIME", datetime.iso8601) + "\n"
      str += XmlResolution.escape("DIGEST",   digest)           + "\n"

      schemas.each do |s|
        next unless s.status == :success
        str += XmlResolution.escape("SCHEMA", s.digest, s.last_modified.iso8601, s.location, s.namespace)   + "\n"
      end

      str += XmlResolution.escape("UNRESOLVED_NAMESPACES", *unresolved_namespaces) + "\n"

      schemas.each do |s|
        next if s.status == :success
        str += XmlResolution.escape("BROKEN_SCHEMA", s.location, s.namespace, s.error_message) + "\n"
      end

      str
    end

    private

    # Extract referenced schemas from the provided string TEXT, an XML
    # document.  If the string SCHEMA_LOCATION, a url, is provided, it
    # indicates that the document is a schema and identifies the source of
    # the document. This method will also analyze plain XML instance
    # documents: in that case, SCHEMA_LOCATION will be nil.
    #
    # Returns a hash mapping locations to namespaces.

    def find_schema_references text, schema_location=nil

      # TODO: on error, this outputs to STDERR.  That won't do!  We'd better dup STDERR to /dev/null around this

      doc = XML::Parser.string(text).parse

      # Get a list of namespaces from the document - initially we don't have a location for any of them

      doc.find("//*").each do |node|
        node.namespaces.each { |ns|  @namespaces_found[ns.href] = false unless @namespaces_found[ns.href] }
      end

      location_namespaces = {}

      # Find any schema locations.

      doc.find('//@xsi:schemaLocation', 'xsi' => 'http://www.w3.org/2001/XMLSchema-instance').each do |sl|
        sl.value.strip.split.each_slice(2) do |ns, url|
          location_namespaces[url] = ns
          @namespaces_found[ns]    = true
        end
      end

      if schema_location   # we're analyzing a schema and we have a location for it; otherwise we're analyzing an XML instance document

        home = schema_location.gsub(/[^\/]*$/, '')
        target_ns = doc.find('//@targetNamespace').first.value    # TODO: bug - not all schemas have targetNamespaces

        doc.find("//xsd:include[@schemaLocation]", 'xsd' => 'http://www.w3.org/2001/XMLSchema').each do |inc|

          url = inc['schemaLocation'] =~ /^http/i ? inc['schemaLocation'] : home + inc['schemaLocation']

          location_namespaces[url]     =  target_ns
          @namespaces_found[target_ns] = true
        end
      end

      location_namespaces

    rescue LibXML::XML::Error => e
      raise XmlParseError, "The XML file could not be parsed: #{e.message}" # TODO: note potential information leakage here and next.
    rescue => e
      raise ResolverError, e.message # Some generic issue - my fault.
    end

    # Attempt to recursively retrieve all of the schemas used for the string TEXT, an XML Document.
    # This method is used to populate the schemas attribute.

    def get_schemas text

      location_namespaces = find_schema_references(text)
      directory           = []
      locations_found     = []

      get_schemas_helper directory, location_namespaces, locations_found

      # sort directory by namespace - that set the order of XmlResolver#schemas

      by_location = {}
      directory.each { |s| by_location[s.location] = s }  # is location a unique key for us? or can an xml instance doc point to the same location for two different namespaces?
      directory = []
      by_location.keys.sort.each { |k| directory.push by_location[k] }
      return directory
    end

    # Recursive helper for get_schemas.  Collects and analyzes
    # schemas.  Recurse on newly extracted schemas.  Returns a list
    # of information about the recovered schemas.  A particular
    # schema will be marked as failed and provided with an error
    # message if there was a problem retrieving or parsing it.


    def get_schemas_helper directory, location_namespaces_to_check, locations_checked

      next_to_check = {}
      location_namespaces_to_check.each do |location, namespace|

        next if locations_checked.member? location
        begin
          response = fetch location

          next_to_check.merge! find_schema_references(response.body, location)

          directory.push OpenStruct.new("body"            => response.body,
                                        "digest"          => Digest::MD5.hexdigest(response.body),
                                        "error_message"   => nil,
                                        "last_modified"   => response['Last-Modified'] ? Time.parse(response['Last-Modified']) : Time.now,
                                        "location"        => location,
                                        "namespace"       => namespace,
                                        "status"          => :success
                                        )
        rescue => e
          directory.push OpenStruct.new("body"            => nil,
                                        "digest"          => nil,
                                        "error_message"   => e.message,
                                        "last_modified"   => nil,
                                        "location"        => location,
                                        "namespace"       => namespace,
                                        "status"          => :failure
                                        )
        ensure
          locations_checked.push location
          locations_checked.each { |already_seen| next_to_check.delete(already_seen) }
        end
      end

      unless next_to_check.empty?
        get_schemas_helper directory, next_to_check, locations_checked
      end
    end

    # Fetch the schema document from the given the string LOCATION, a
    # URL. Returns a Net::HTTP response object.  The number of
    # followed redirects is limited to 5. Raises a variety of
    # exceptions, which are generally handled within this class (an
    # error message for this particular schema is recorded and the
    # status is marked as a failure, and we move on).

    def fetch location, limit = 5

      uri = URI.parse location

      raise LocationError, "#{uri.scheme} is not a supported protocol - #{location} not retrieved."  unless uri.scheme == 'http'
      raise LocationError, "#{location} can't be retrieved, there were too many redirects."          if limit < 1

      # TODO: We plan to run this under Sinatra, but Net::HTTP::Proxy isn't thread safe.  Fix me!

      # Note: if proxy_addr & proxy_port are nil,  Net::HTTP::Proxy is equivalent to Net::HTTP

      Net::HTTP::Proxy(proxy_addr, proxy_port).start(uri.host, uri.port) do |http|
        response  = http.get(uri.path)
        case response
        when Net::HTTPSuccess     then response
        when Net::HTTPRedirection then fetch response['location'], limit - 1
        else
          response.error!
        end
      end
    end # of fetch
  end # of class XmlResolver

  # The XmlResolverReloaded class lets us duck type as much of
  # XmlResolver as we can from its dump output, which is what we use
  # (as a string) in its constructor. See the docs for
  # XmlResolver#dump above for the details on the dump format, which
  # is a simple text file.

  class XmlResolverReloaded

    # schemas provides a list of information about the schemas needed to analyze a document

    attr_reader :schemas
    attr_reader :filename
    attr_reader :digest
    attr_reader :unresolved_namespaces
    attr_reader :datetime
    attr_reader :local_uri

    def initialize  text

      @schemas               = []
      @unresolved_namespaces = []
      @filename              = nil
      @digest                = nil

      text.split("\n").each do |line|
        data = XmlResolution.unescape line

        case data.shift

        when 'DATE_TIME' then @datetime  = Time.parse data.shift
        when 'DIGEST'    then @digest    = data.shift
        when 'FILE_NAME' then @filename  = data.shift
        when 'LOCAL_URI' then @local_uri = data.shift

        when 'UNRESOLVED_NAMESPACES' then @unresolved_namespaces = data

        when 'SCHEMA'
          @schemas.push OpenStruct.new("body"            => nil,
                                       "digest"          => data.shift,
                                       "last_modified"   => Time.parse(data.shift),
                                       "location"        => data.shift,
                                       "namespace"       => data.shift,
                                       "status"          => :success,
                                       "error_message"   => nil)

        when 'BROKEN_SCHEMA'
          @schemas.push OpenStruct.new("body"            => nil,
                                       "digest"          => nil,
                                       "last_modified"   => nil,
                                       "location"        => data.shift,
                                       "namespace"       => data.shift,
                                       "status"          => :failure,
                                       "error_message"   => data.shift)
        end # of case
      end # of split
    end # of def
  end # of class XmlResolverReloaded
end # of module XmlResolution
# ha!
