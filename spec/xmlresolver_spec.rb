require 'xmlresolution/xmlresolver'
require 'xmlresolution/exceptions'

describe XmlResolution::XmlResolver do

  @@mets_xres = nil                           # we'll fill this in later

  def test_proxy
    "satyagraha.sacred.net"
  end


  def mets_namespace 
    "http://www.loc.gov/METS/"
  end

  def mets_location 
    "http://www.loc.gov/standards/mets/mets.xsd"    
  end

  def example_mets_document
    File.read(File.join(File.dirname(__FILE__), 'files', 'example-xml-documents', 'F20060215_AAAAHL.xml'))
  end

  def example_non_xml_document
    File.read("/etc/passwd")
  end

  it "should let us initialize without proxy information, and get nil for proxy port and address" do
    xres = XmlResolution::XmlResolver.new "<root/>"
    xres.proxy_port.should == nil
    xres.proxy_addr.should == nil
  end

  it "should let us initialize with just host proxy information, and get 3128 for proxy port and the initialized address" do
    xres = XmlResolution::XmlResolver.new "<root/>", test_proxy
    xres.proxy_port.should == 3128
    xres.proxy_addr.should == test_proxy
  end

  it "should let us initialize with proxy host and port information, and get back the initialized proxy port and the initialized address" do
    xres = XmlResolution::XmlResolver.new "<root/>", "example.com:80"
    xres.proxy_port.should == 80
    xres.proxy_addr.should == "example.com"
  end

  it "should have no schema information from a stand-alone document" do
    xres = XmlResolution::XmlResolver.new "<root/>"
    xres.schemas.length.should == 0
  end

  it "should raise an XmlResolverException when passed non-xml files" do
    lambda { XmlResolution::XmlResolver.new example_non_xml_document, test_proxy }.should raise_error(XmlResolution::XmlParseError)
  end

  it "should get schema information from a typical METS descriptor" do
    @@mets_xres = XmlResolution::XmlResolver.new example_mets_document, test_proxy
    @@mets_xres.schemas.length.should_not == 0
  end

  it "should get some typical unresolved namespaces for a typical METS descriptor" do
    un = @@mets_xres.unresolved_namespaces

    un.include?("http://www.w3.org/1999/xlink").should == true
    un.include?("http://www.w3.org/2001/XMLSchema-hasFacetAndProperty").should == true
    un.include?("http://www.w3.org/2001/XMLSchema-instance").should == true
  end

  it "should get the METS namespace from among the schemas fetched for a typical METS descriptor" do
    @@mets_xres.schemas.map { |elt| elt.namespace }.include?(mets_namespace).should == true
  end

  it "should get the METS schema location from among the schemas fetched for a typical METS descriptor" do
    @@mets_xres.schemas.map { |elt| elt.location }.include?(mets_location).should == true
  end

end
