require 'xmlresolution/xmlresolver'
require 'xmlresolution/exceptions'
require 'uri'

STDERR.puts "Expect the message \"Fatal error: Start tag expected, '<' not found at :1.\" It's from LibXML."

describe XmlResolution::XmlResolver do

  before(:all) do 
    STDERR.puts "Warning: no HTTP_PROXY environment variable found. Winging it." unless ENV['HTTP_PROXY']    
  end

  @@mets_xres     = nil                           # we'll fill this in later
  @@mets_reloaded = nil
  @@filename      = 'file://campy.flca.edu/C:/Documents and Settings/Sheldon/bicycle.xml'
  @@local_uri     = 'file://example.com/var/tmp/data/collections/E20100110_CAFEED/a166f873a7607ebcec83c01354f300af'

  def test_proxy
    ENV['HTTP_PROXY']
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
    xres = XmlResolution::XmlResolver.new "<root/>", 'example.com'
    xres.proxy_port.should == 3128
    xres.proxy_addr.should == 'example.com'
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
    @@mets_xres.schemas.length.should > 10
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

  it "should give us a data dump representation of itself" do
    (@@mets_xres.dump =~ /^UNRESOLVED_NAMESPACES /).should_not == nil
    (@@mets_xres.dump =~ /^SCHEMA /).should_not == nil
  end

  it "should give us a digest of the document text" do
    (@@mets_xres.dump =~ /^DIGEST [a-f0-9]{32}/).should_not == nil
  end

  it "should not include a filename yet" do
    (@@mets_xres.dump =~ /^FILE_NAME /).should == nil
  end

  it "should let us add a filename" do
    @@mets_xres.filename = @@filename
    @@mets_xres.filename.should == @@filename
  end

  it "should now include the filename in the dump" do
    (@@mets_xres.dump =~ /^FILE_NAME /).should_not == nil
    (@@mets_xres.dump =~ /#{URI.escape(@@filename)}/).should_not == nil
  end

  it "should not include a local uri yet" do
    (@@mets_xres.dump =~ /^LOCAL_URI /).should == nil
  end

  it "should let us add a local uri" do
    @@mets_xres.local_uri = @@local_uri
    @@mets_xres.local_uri.should == @@local_uri
  end

  it "should now include the local_uri in the dump" do
    (@@mets_xres.dump =~ /^LOCAL_URI /).should_not == nil
    (@@mets_xres.dump =~ /#{URI.escape(@@local_uri)}/).should_not == nil
  end

  it "should allow us to recreate much of its behavior by using the dump in a duck-class" do
    lambda { @@mets_reloaded = XmlResolution::XmlResolverReloaded.new @@mets_xres.dump }.should_not raise_error
  end

  it "should match the digest in it's duck-class" do
    @@mets_xres.digest.should == @@mets_reloaded.digest
  end

  it "should match the filename in it's duck-class" do
    @@mets_xres.filename.should == @@mets_reloaded.filename
  end

  it "should match the schema data in it's duck-class" do
    @@mets_xres.schemas.length.should == @@mets_reloaded.schemas.length
  end

  it "should match the internal data in it's duck-class" do
    @@mets_xres.datetime.iso8601.should  == @@mets_reloaded.datetime.iso8601
    @@mets_xres.filename.should          == @@mets_reloaded.filename
    @@mets_xres.local_uri.should         == @@mets_reloaded.local_uri

    @@mets_xres.schemas[0].digest.should            == @@mets_reloaded.schemas[0].digest
    @@mets_xres.schemas[0].modification_time.should == @@mets_reloaded.schemas[0].modification_time
    @@mets_xres.schemas[0].location.should          == @@mets_reloaded.schemas[0].location
    @@mets_xres.schemas[0].namespace.should         == @@mets_reloaded.schemas[0].namespace
    @@mets_xres.schemas[0].status.should            == @@mets_reloaded.schemas[0].status
  end

  # The following is lame.  But how far should we go? Use Schematron to check?

  it "should produce a premis report of what it has done" do
    premis = XmlResolution.xml_resolver_report @@mets_xres, 'http://xmlresolution.dev.flca.edu/'
    STDERR.puts premis
    (premis =~ /<premis.*>.*<\/premis>$/mi).should_not == nil
  end

end
