require 'digest/md5'
require 'libxml'
require 'net/http'
require 'uri'
require 'time'      # brings in parse method, iso8601, xmlschema
require 'ostruct'
require 'xmlresolution/exceptions'

include LibXML

module XmlResolution

# TODO: extend to DTDs.  Produce 400 for XML Files that fail entirely (e.g. non-xml)

# Author: Randy Fischer (rf@ufl.edu) for DAITSS

# This class analyzes an XML document, attempting to retrieve the
# schema documents required to correctly validate it. It will
# optionally use an HTTP caching proxy such as squid to recursively
# fetch the schemas.  A list of namespaces that were not able to be
# resolved can be retrieved using the #unresolved_namespaces method.
#
# The contents of the schema files are available in the
# #schema_information record (a hash) under the :body key.
#
# Example usage:
#
#   xrez = XmlResolver.new(File.read("F20060215_AAAAHL.xml"), "satyagraha.sacred.net:3128")
#   xrez.schemas.each do |rec| 
#     next unless rec[:status] == :success
#     puts rec[:namespace] + " => " + rec[:location] 
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

    # The schema attribute holds a list of structs, where
    # each struct has accessors defined as so:
    #
    #   * location        => url-string
    #   * last_modified   => DateTime
    #   * namespace       => urn-string
    #   * status          => [ :success | :failure ]
    #   * error_message   => [ string | nil ]
    #   * digest          => [ md5-hex-string | nil ]
    #   * body            => [ string | nil ],
    #   * processing_time => Float 
    #
    # The .body slot contains the schema document itself,
    # .processing_time gives the number of seconds to request and
    # retrieve the schema, and .last_modified gives the last
    # modification time of the retrieved document.
    #
    # proxy_port and proxy_addr hold the hostname/port of the http proxy,
    # if specified.

    attr_reader :proxy_port, :proxy_addr, :schemas

    # Create an XML resolver object given an xml docment in the string
    # XML_TEXT. Optionally provide the string CACHING_HTTP_PROXY, naming
    # a caching proxy to use when retrieving schemas or DTDs (format
    # "hostname:port",  port defaults to 3128). 

    def initialize xml_text, caching_http_proxy = nil
      @namespaces_found = {}

      @proxy_port = @proxy_addr = nil   # possible to have no proxy - then we'll contact locations directly

      if caching_http_proxy      
        @proxy_addr, @proxy_port = caching_http_proxy.split(':', 2)
        if @proxy_port.nil?
          @proxy_port = 3128 
        else 
          @proxy_port = @proxy_port.to_i
        end
      end

      @schemas = get_schemas xml_text
    end


    # Return a list of namespaces that were encountered, but never had a location associated with them.

    def unresolved_namespaces
      @namespaces_found.collect { |namespace, located| namespace if not located }.compact.sort
    end


    private

    # Extract referenced schemas from the provided string TEXT, an XML
    # document.  If the string SCHEMA_LOCATION, a url, is provided, it
    # identifies the source of the document. This method will also
    # analyze plain XML instance documents: in that case,
    # SCHEMA_LOCATION will be nil.
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
      raise XmlParseError, e.message
    rescue => e
      raise ResolverError, e.message 
    end

    # Attempt to recursively retrieve all of the schemas used for the string TEXT, an XML Document.
    # This method is used to populate the #schema_information attribute.
    #
    # This is designed so that exceptions from #find_schema_references are not caught - anything
    # else should be properly fielded.

    def get_schemas text

      location_namespaces = find_schema_references(text)    
      directory           = []
      locations_found     = []

      get_schemas_helper directory, location_namespaces, locations_found
      return directory
    end

    # Recursive helper for get_schemas.  Collects and analyzes schemas.
    # Recurse.  Returns a list of information about the recovered
    # schemas.  A particular schema will be marked as failed and
    # provided with an error message if there was a problem retrieving
    # or parsing it.

    def get_schemas_helper directory, location_namespaces_to_check, locations_checked

      next_to_check = {}
      location_namespaces_to_check.each do |location, namespace|

        next if locations_checked.member? location
        time = Time.now

        begin
          response = fetch location        

          next_to_check.merge!(find_schema_references(response.body, location))

          directory.push(OpenStruct.new("body"            => response.body,
                                        "digest"          => Digest::MD5.hexdigest(response.body), 
                                        "error_message"   => nil,
                                        "last_modified"   => response['Last-Modified'] ? Time.parse(response['Last-Modified']) : Time.now,
                                        "location"        => location,
                                        "namespace"       => namespace,
                                        "processing_time" => (Time.now - time),
                                        "status"          => :success
                                        ))
        rescue => e
          directory.push(OpenStruct.new("body"            => nil,
                                        "digest"          => nil,
                                        "error_message"   => e.message,
                                        "last_modified"   => nil,
                                        "location"        => location,
                                        "namespace"       => namespace,
                                        "processing_time" => (Time.now - time),
                                        "status"          => :failure
                                        ))
        ensure
          locations_checked.push location
          locations_checked.each { |already_seen| next_to_check.delete(already_seen) }
        end
      end

      unless next_to_check.empty?
        get_schemas_helper directory, next_to_check, locations_checked 
      end
    end

    # Fetch the document from the given the string LOCATION, a
    # URL. Returns a Net::HTTP response object.  The number of followed
    # redirects is limited to 5. Raises a variety of exceptions, which
    # are always handled within this class.

    def fetch location, limit = 5

      uri = URI.parse location

      raise LocationError, "#{uri.scheme} is not a supported protocol - #{location} not retrieved."  unless uri.scheme == 'http'    
      raise LocationError, "#{location} can't be retrieved, there were too many redirects."          if limit < 1

      # TODO: We plan to run this under Sinatra, but Net::HTTP::Proxy isn't thread safe.  Fix me!
      #
      # Note: if proxy_addr & proxy_port are nil, this is equivalent to Net::HTTP

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

  end # of class

end # of module
