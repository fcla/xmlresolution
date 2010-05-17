require 'nokogiri'
require 'time'
require 'uri'


# Class PlainXmlDocument subclasses a Nokogiri::XML::SAX::Document
# with basic SAX event callbacks, namely:
#
#   * start_element_namespace
#   * end_element_namespace
#   * error
#   * warning
#   * xml_decl
#
# Analysis of the elements provided by the first of these callbacks
# allows us to record the namespaces that are actually used by elements
# and their attributes.  Errors, warnings, and the XML declaration are
# also collected in the course of the parsing.  Methods are added to
# the PlainXmlDocument class to return these data.
#
# The XML document text to be analyzed is not directly provided to this 
# object; rather, the XML document is used in concert with this class
# and the SAX::PArser as so:
#
#      document = PlainXmlDocument.new
#      Nokogiri::XML::SAX::Parser.new(document).parse(XML-DOCUMENT-TEXT)
#      return document
#
# TODO:
#   Is it worth it to handle xsi:noNamespaceSchemaLocation (includes?)

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
  # The purpose of this document class is to garner a list of
  # namespaces actually used by a document.  The optional
  # USED_NAMESPACE hash, if given, will be augmented by namespaces
  # encountered in the document.  USED_NAMESPACES is a hash where only
  # the keys (Namespace URNs) are important.
  #
  # DOC will eventually be passed to Nokogiri::XML::SAX::Parser to be
  # populated; see the XmlResolution::XMLResolver class.

  def initialize used_namespaces = {}
    @used_namespaces = used_namespaces
    @locations  = {}
    @namespace_declarations_stack  = []
    @warnings = []
    @errors   = []
    @version  = '1.0'
    super()
  end

  # Standard callbacks:

  # xmldecl  VERSION, ENCODING, STANDALONE
  #
  # Called when an XML declaration node is encountered; we record the XML version
  # as the object attribute version, which defaults to '1.0'

  def xmldecl version, encoding, standalone
    @version = version unless version.nil?
  end

  # start_element_namespace ELEMENT_NAME, ATTRIBUTES, PREFIX, URI, NAMESPACE
  #
  # SAX calls this method as it encounters new elements.  We mine the
  # elements and attributes for their namespace URIs; we also quick
  # check for schemaLocation elements. Note that the namespace for
  # this element is included as the URI; NAMESPACE is an array all the
  # xmlns declarations for this node, whach may include namespaces not
  # actually used by the document.

  def start_element_namespace element_name, attributes = [], prefix = nil, uri = nil, namespace = []
    @namespace_declarations_stack.push namespace
    @used_namespaces[uri] = true unless uri.nil?
    attributes.each { |a| @used_namespaces[a.uri] = true unless a.uri.nil? }
    check_for_locations attributes
  end

  # end_element_namespace ELEMENT_NAME, PREFIX, URI
  #
  # Used only to pop the namespace declarations stack.

  def end_element_namespace element_name, prefix = nil, uri = nil
    @namespace_declarations_stack.pop
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
  # occurs during document processing we record the message on the
  # warnings attribute, an array of strings.

  def warning string
    warnings.push string.chomp
  end

  # namespaces
  #
  # Returns a hash of namespaces extracted from the element and
  # attribute information parsed by the SAX processor: only those
  # namespaces actually used by the XML document are recorded.  The
  # optional argument to the constructor is used if provided, and will
  # reflect the addtional namespaces added in the course of SAX
  # parsing.
 

  def used_namespaces
    @used_namespaces
  end

  # locations
  #
  # Returns a hash of Location-URL/Namespace-URN key/value pairs 
  # where the use of a Namespace-URN has been encountered during element
  # and attribute parsing.
  #
  # TODO: can <xsd:attributeGroup ref="xlink:simpleLink"/> occur with xlink having been resolved?

  def namespace_locations
    used_locations = Hash.new
    @locations.keys.each do |loc|
      used_locations[loc] =  @locations[loc] if @used_namespaces[@locations[loc]]
    end
    used_locations
  end

  # check_for_locations ATTRIBUTES
  #
  # Given the array ATTRIBUTES of the SAX-parsed attributes object
  # (which include the methods 'localname', 'prefix', 'uri' and
  # 'value' such that where 'uri' is the namespace of the unprefixed
  # attribute name 'localname'), check if it includes a schemaLocation 
  # and if so, parse its values, adding to the internal @locations hash.
  #
  # Consider this piece of a METs instance document:
  #
  # <METS:mets xmlns:METS="http://www.loc.gov/METS/"
  #            xmlns:daitss="http://www.fcla.edu/dls/md/daitss/"
  #            xmlns:dc="http://purl.org/dc/elements/1.1/"
  # 	       xmlns:mods="http://www.loc.gov/mods/v3"
  #            xmlns:palmm="http://www.fcla.edu/dls/md/palmm/"
  #            xmlns:rightsmd="http://www.fcla.edu/dls/md/rightsmd/"
  #            xmlns:techmd="http://www.fcla.edu/dls/md/techmd/"
  #            xmlns:xlink="http://www.w3.org/1999/xlink"
  #            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  #            LABEL="Florida Chautauqua" OBJID="SN00000005"
  #            TYPE="serial"
  #            xsi:schemaLocation="http://www.loc.gov/METS/             http://www.loc.gov/standards/mets/mets.xsd
  #                                http://purl.org/dc/elements/1.1/     http://dublincore.org/schemas/xmls/simpledc20021212.xsd
  #                                http://www.loc.gov/mods/v3           http://www.loc.gov/standards/mods/v3/mods-3-0.xsd
  #                                http://www.fcla.edu/dls/md/techmd/   http://www.fcla.edu/dls/md/techmd.xsd
  #                                http://www.fcla.edu/dls/md/palmm/    http://www.fcla.edu/dls/md/palmm.xsd
  #                                http://www.fcla.edu/dls/md/rightsmd/ http://www.fcla.edu/dls/md/rightsmd.xsd
  #                                http://www.fcla.edu/dls/md/daitss/   http://www.fcla.edu/dls/md/daitss/daitss.xsd">
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

  # TODO: no longer using the default_namespace method or @namespace_declarations_stack.
  # Remove when sure there's no use case.

  # default_namespace
  #
  # Determines the defaultNamespace in the current parsing context.
  #
  # A word on the @namespace_declarations_stack: we have need,
  # occasionally to find the default namespace.  This stack lets us
  # maintain the scope.  it is an array of array of arrays:
  #
  #   Stack:     [
  #     First:     [  ["gesmes", "http://www.gesmes.org/xml/2002-08-01"], [nil, "http://www.ecb.int/vocabulary/2002-08-01/eurofxref"]  ]
  #    Second:     [                                                                                            ]
  #   End Stack: ]
  #
  # In the above we have the result of having parsed into the following document, at the point of the '***'
  #
  # <?xml version="1.0" encoding="UTF-8"?>
  # <gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01"
  #                  xmlns="http://www.ecb.int/vocabulary/2002-08-01/eurofxref">
  #   <gesmes:subject>Reference rates</gesmes:subject>
  #   <gesmes:Sender>
  #   ***
  #     <gesmes:name>European Central Bank</gesmes:name>
  #     </gesmes:Sender>
  #   <Cube>
  #      <Cube time="2009-11-03">
  #        <Cube currency="USD" rate="1.4658"/>
  #        <Cube currency="JPY" rate="132.25"/>
  #        <Cube currency="BGN" rate="1.9558"/>
  #      </Cube>
  #   </Cube>
  # </gesmes:Envelope>
  #
  # The first stack element shows the "gesmes" prefix and its
  # definition, as well as the default namespace declaration,
  # indicated by the nil value. The second is turns out to be empty,
  # but it must be there to maintain the context when we pop off.
  #
  # Now the Nokogiri SAX does do a great job of maintaining the
  # current namespace for each element and attribute.  We maintain
  # this stack, however to catch an edge case in schema processing, to
  # get at the default namespace in an include [BLAH BLAH..make sure I
  # know what I'm talking about here]

  def default_namespace
    @namespace_declarations_stack.reverse.each do |list_of_pairs|
      list_of_pairs.each do |pair|
        prefix, namespace = pair
        return namespace if prefix.nil?
      end
    end
    nil
  end

end # of class PlainXmlDocument

class SchemaDocument < PlainXmlDocument


  # # # @@indent = [ '' ]
  # # # def indent *args                                                                                                                          
  # # #   STDERR.puts  @@indent.join('. ') + args.join(' ')                                                                                              
  # # # end                                                                                                                                       

  @schema_location  = nil
  @target_namespace = nil
 
  def initialize schema_location, used_namespaces
    raise "Schema location #{schema_location} must be an absoulte URI: it wasn't." unless URI.parse(schema_location).absolute?
    @schema_location = schema_location
    super(used_namespaces)
  end

  def absolutize location
    return location if URI.parse(location).absolute?
    return URI.join(@schema_location, location).to_s
  end

  # Good old SAX: on entry to each element, the following callback is called back.
  # 

  def start_element_namespace name, attributes = [], prefix = nil, uri = nil, ns = []
    super

    # # # @@indent.push ''                                                                                                                                                                                                                                                                    
    # # # indent 'Start', name, '(' + [prefix, uri].join(':') + ')'                                                                               
    # # # attributes.each do |a|                                                                                                                  
    # # #   indent '   attr:', a.inspect                                                                                                          
    # # # end                                                                                                                                     
    # # # ns.each  do |n|                                                                                                                         
    # # #   indent '     ns:', n.inspect                                                                                                          
    # # # end                                                                                                                                     

    get_import_location  attributes if name == 'import'  and uri == 'http://www.w3.org/2001/XMLSchema'
    get_include_location attributes if name == 'include' and uri == 'http://www.w3.org/2001/XMLSchema'
    get_target_namespace attributes if name == 'schema'  and uri == 'http://www.w3.org/2001/XMLSchema'
  end

  # # # def end_element_namespace name, prefix = nil, uri = nil                                                                                   
  # # #   indent 'End', name, '(' + [prefix, uri].join(':') + ')'                                                                                 
  # # #   @@indent.pop                                                                                                                            
  # # # end          

  # Assumes we're called from an element node named "http://www.w3.org/2001/XMLSchema:schema".

  def get_target_namespace attributes
    attributes.each do |attr|
      if attr.localname == 'targetNamespace' and (attr.uri.nil? or attr.uri == 'http://www.w3.org/2001/XMLSchema')
        @target_namespace = attr.value
      end
    end
  end

  # extract and add the namespace/location mapping for schema directives of the form:
  #
  #   <"http://www.w3.org/2001/XMLSchema":import
  #          namespace="http://www.w3.org/XML/1998/namespace"
  #          schemaLocation="http://www.w3.org/2001/xml.xsd">
  #

  def get_import_location attributes
    loc = nil
    ns  = nil
    attributes.each do |attr|
      ns  = attr.value if attr.localname == 'namespace'
      loc = attr.value if attr.localname == 'schemaLocation'
    end

    if ns and loc
      @used_namespaces[ns] = true
      @locations[absolutize(loc)] = ns 
    end
  end

  # get_include_location handles xsd:include directives.
  #
  # <xsd:schema .... >
  #    <xsd:include schemaLocation="daitssAccount.xsd"/>
  #    <xsd:include schemaLocation="daitssAccountProject.xsd"/>
  #     ....
  #
  # By definition, includes are for the targetNamespace.

  def get_include_location attributes
    attributes.each do |attr|
      next unless attr.localname == 'schemaLocation'
      @locations[absolutize(attr.value)] = @target_namespace
    end
  end
end # of class SchemaDocument

