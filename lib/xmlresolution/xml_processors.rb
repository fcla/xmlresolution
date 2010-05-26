require 'nokogiri'
require 'time'
require 'uri'

# TODO:
# Is it worth it to handle xsi:noNamespaceSchemaLocation (includes?)


# Class PlainXmlDocument subclasses Nokogiri::XML::SAX::Document
#
# The purpose of PlainXmlDocument is to work in concert with the 
# Nokogiri SAX parser to analyze a submitted XML Document.
# It accumulates information about namespaces and schema
# locations in the XML Document.
# 
# The XML document text to be analyzed is not directly accessed
# by the PlainXmlDocument object; rather, the XML document is used in concert
# with the object and the SAX::Parser, as in the following example:
#
#      document = PlainXmlDocument.new
#      Nokogiri::XML::SAX::Parser.new(document).parse(XML-DOCUMENT-TEXT)
#      ... use document methods ...
#
# The PlainXmlDocument object registers callbacks with the SAX parser.
# We register only a few of the basic SAX event callbacks, namely:
#
#   * start_element_namespace
#   * error
#   * warning
#   * xml_decl
#
# Analysis of the elements provided by the first of these callbacks
# allows us to record the namespaces that are actually used by
# elements and their attributes.  Errors, warnings, and the XML
# declaration are also collected in the course of the parsing.
# Methods are added to the PlainXmlDocument class to return these
# data.

class PlainXmlDocument < Nokogiri::XML::SAX::Document

  # An array of strings, these are all of the warnings issued by the SAX parser when this object is processed.

  attr_reader :warnings

  # An array of strings, these are all of the errors issued by the SAX parser when this object is processed.

  attr_reader :errors

  # The string version for the XML document as extracted from the XMl declaration; if no such declaration
  # encountered, '1.0'.

  attr_reader :version

  # DOC = PlainXmlDocument.new [ USED_NAMESPACES ]
  # 
  # The purpose of this object is to garner a list of namespaces
  # actually used by a document.  The optional USED_NAMESPACE hash, if
  # given, will be augmented by namespaces encountered in the
  # document.  USED_NAMESPACES is a hash where only the keys
  # (Namespace URNs) are important.
  #
  # DOC will eventually be passed to Nokogiri::XML::SAX::Parser to be
  # populated; see the XmlResolution::XMLResolver class.

  def initialize used_namespaces = {}
    @errors     = []
    @locations  = {}
    @version    = '1.0'
    @warnings   = []
    @used_namespaces = used_namespaces
    super()
  end

  # used_namespaces
  #
  # Returns a hash of the namespaces extracted from the element and
  # attribute information parsed by the SAX processor: only those
  # namespaces actually used by the XML document are recorded.  This
  # will be identical to the optional hash argument to our constructor
  # if it was provided.
 
  def used_namespaces
    @used_namespaces
  end

  # TODO: can <xsd:attributeGroup ref="xlink:simpleLink"/> occur with
  # xlink not having been already resolved? Apparently not...

  # namespace_locations
  #
  # Returns a hash of Location-URL/Namespace-URN key/value pairs 
  # where the use of a Namespace-URN has been encountered during element
  # and attribute parsing.

  def namespace_locations
    used_locations = Hash.new
    @locations.keys.each do |loc|
      used_locations[loc] =  @locations[loc] if @used_namespaces[@locations[loc]]
    end
    used_locations
  end


  private

  # Standard callbacks:

  # xmldecl  VERSION, ENCODING, STANDALONE
  #
  # Called when an XML declaration node is encountered; we record the XML version
  # as the object attribute version, otherwise defaults to '1.0'

  def xmldecl version, encoding, standalone
    @version = version unless version.nil?
  end

  # start_element_namespace ELEMENT_NAME, ATTRIBUTES, PREFIX, URI, NAMESPACE
  #
  # SAX calls this method as it encounters new elements.  We mine the
  # elements and attributes for their namespace URIs; we also check
  # for schemaLocation elements. Note that the namespace for this
  # element is included as the URI; NAMESPACE is an array  of
  # the xmlns declarations for this node (if nay), which may
  # include namespaces not actually used by the document.

  def start_element_namespace element_name, attributes = [], prefix = nil, uri = nil, namespace = []
    @used_namespaces[uri] = true unless uri.nil?
    attributes.each do |a| 
      @used_namespaces[a.uri] = true unless a.uri.nil?
    end
    check_for_locations attributes
  end

  # error STRING
  #
  # STRING provides a message encountered when an error condition occurs
  # during document parsing; we record the message on the 
  # errors attribute, an array of strings.

  def error string
    errors.push string.chomp
  end

  # warning STRING
  #
  # STRING provides a message encountered when a warning condition
  # occurs during document processing; we record the message on the
  # warnings attribute, an array of strings.

  def warning string
    warnings.push string.chomp
  end


  # check_for_locations ATTRIBUTES
  #
  # Given the array ATTRIBUTES of the SAX-parsed attributes object
  # (which include the methods 'localname', 'prefix', 'uri' and
  # 'value' such that 'uri' is the namespace of the unprefixed
  # attribute name 'localname'), check if it includes a schemaLocation 
  # and if so, parse its values, adding to the internal @locations hash.
  #
  # Consider this fragment of a METs instance document:
  #
  #    <METS:mets xmlns:METS="http://www.loc.gov/METS/"
  #               xmlns:daitss="http://www.fcla.edu/dls/md/daitss/"
  #               xmlns:dc="http://purl.org/dc/elements/1.1/"
  # 	          xmlns:mods="http://www.loc.gov/mods/v3"
  #               xmlns:palmm="http://www.fcla.edu/dls/md/palmm/"
  #               xmlns:rightsmd="http://www.fcla.edu/dls/md/rightsmd/"
  #               xmlns:techmd="http://www.fcla.edu/dls/md/techmd/"
  #               xmlns:xlink="http://www.w3.org/1999/xlink"
  #               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  #
  #           LABEL="Florida Chautauqua" OBJID="SN00000005"
  #           TYPE="serial"
  #
  #      xsi:schemaLocation="http://www.loc.gov/METS/             http://www.loc.gov/standards/mets/mets.xsd
  #                          http://purl.org/dc/elements/1.1/     http://dublincore.org/schemas/xmls/simpledc20021212.xsd
  #                          http://www.loc.gov/mods/v3           http://www.loc.gov/standards/mods/v3/mods-3-0.xsd
  #                          http://www.fcla.edu/dls/md/techmd/   http://www.fcla.edu/dls/md/techmd.xsd
  #                          http://www.fcla.edu/dls/md/palmm/    http://www.fcla.edu/dls/md/palmm.xsd
  #                          http://www.fcla.edu/dls/md/rightsmd/ http://www.fcla.edu/dls/md/rightsmd.xsd
  #                          http://www.fcla.edu/dls/md/daitss/   http://www.fcla.edu/dls/md/daitss/daitss.xsd">
  #
  # check_for_locations parses the "xsi:schemaLocation" attribute into namespace-uri/location-url pairs, and
  # enters them into the @locations hash, which maintains an association of locations and the namespace.

  def check_for_locations attributes
    attributes.each do |attr|
      if attr.localname == 'schemaLocation' and attr.uri == 'http://www.w3.org/2001/XMLSchema-instance'
        pairs = attr.value.split(/\s+/)
        while not pairs.empty?
          ns, loc = pairs.slice!(0..1)
          @locations[loc] = ns unless loc.nil? 
        end
      end
    end
  end

end # of class PlainXmlDocument


# Class SchemaDocument subclasses PlainXmlDocument, which in turn is
# a subclass of Nokogiri::XML::SAX::Document.
#
# It adds no additional callbacks to those established by PlainXmlDocument.
# Instead, it adds specialized processing for schema documents, looking for
# the following elements:
#
#   'http://www.w3.org/2001/XMLSchema':import
#   'http://www.w3.org/2001/XMLSchema':include
#   'http://www.w3.org/2001/XMLSchema':schema 
#
# Attributes for these elements are mined for additional schema
# locations to process.

class SchemaDocument < PlainXmlDocument

  # The URL for this schema.  Currently, only HTTP schemes are supported.

  @schema_location  = nil

  # If a targetNamespace attribute is encountered, this will contain it. 

  @target_namespace = nil
 
  # SchemaDocument.new LOCATION, USED_NAMESPACES
  #
  # As in PlainXmlDocument, USED_NAMESPACES is a hash of namespaces
  # URNs where the values are not important. It is used in the
  # constructor so that calling applications can reuse it for
  # subsequent invocations: effectively, we inherit the parent's
  # schema namespaces.
  #
  # Because schemaLocation declarations may include relative URLs, we
  # must include the URL of the schema document, the string LOCATION.

  def initialize schema_location, used_namespaces
    raise "Schema location #{schema_location} must be an absoulte URI: it wasn't." unless URI.parse(schema_location).absolute?
    @schema_location = schema_location
    super(used_namespaces)
  end

  private

  # absolutize LOCATION
  #
  # Given the URL LOCATION, attempt to turn it into an absolute URL. It is done relative
  # to our object's schema_location, a required parameter in the contstructor.

  def absolutize location
    return location if URI.parse(location).absolute?
    return URI.join(@schema_location, location).to_s
  end

  # start_element_namespace ELEMENT_NAME, ATTRIBUTES, PREFIX, URI, NAMESPACE
  #
  # After the PlainXmlDocument superclass has it's way, check for schema-specific 
  # attributes that may cause us to add additional schema locations.

  def start_element_namespace element_name, attributes = [], prefix = nil, uri = nil, namespace = []
    super
    if uri == 'http://www.w3.org/2001/XMLSchema'
      case element_name
      when 'schema';   get_target_namespace attributes
      when 'import';   get_import_location  attributes
      when 'include';  get_include_location attributes
      end
    end
  end

  # get_target_namespace ATTRIBUTES
  #
  # Extract the targeNamespace if found in ATTRIBUTES, an array of
  # Nokogiri::XML::SAX::Parser::Attribute structs. We're called when
  # an element node named "http://www.w3.org/2001/XMLSchema":schema is
  # encountered.

  def get_target_namespace attributes
    attributes.each do |attr|
      if attr.localname == 'targetNamespace' and (attr.uri.nil? or attr.uri == 'http://www.w3.org/2001/XMLSchema')
        @target_namespace = attr.value
        @used_namespaces[@target_namespace] = true
      end
    end
  end

  # get_import_location ATTRIBUTES
  #
  # Search through ATTRIBUTES (essentially an array of
  # Struct.new(:localname, :prefix, :uri, :value)). We extract the
  # namespace/location mappings for schema import directives of the
  # form:
  #
  #   <"http://www.w3.org/2001/XMLSchema":import
  #          namespace="http://www.w3.org/XML/1998/namespace"
  #          schemaLocation="http://www.w3.org/2001/xml.xsd">


  def get_import_location attributes
    loc = nil
    ns  = nil
    
    # search through all attributes for those of interest; if we find both a namespace
    # and schemaLocation record them.

    attributes.each do |attr|
      ns  = attr.value if attr.localname == 'namespace'
      loc = attr.value if attr.localname == 'schemaLocation'
    end

    if ns and loc
      @used_namespaces[ns] = true
      @locations[absolutize(loc)] = ns 
    end
  end

  # get_include_location ATTRIBUTES
  # 
  # Handle schema include directives, searching through the attributes
  # associated with "http://www.w3.org/2001/XMLSchema":include
  # elements.  By definition, includes import into the target
  # namespace.
  #
  #   <xsd:schema .... >
  #       <xsd:include schemaLocation="daitssAccount.xsd"/>
  #       <xsd:include schemaLocation="daitssAccountProject.xsd"/>
  #        ....

  def get_include_location attributes
    attributes.each do |attr|
      next unless attr.localname == 'schemaLocation'
      @locations[absolutize(attr.value)] = @target_namespace
    end
  end
end # of class SchemaDocument

