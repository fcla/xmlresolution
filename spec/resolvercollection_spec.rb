require 'tmpdir'

require 'xmlresolution/resolvercollection'
require 'xmlresolution/xmlresolver'
require 'xmlresolution/exceptions'

describe XmlResolution::ResolverCollection do

  before(:all) do 
    STDERR.puts "Warning: no RESOLVER_PROXY environment variable found. Winging it." unless ENV['RESOLVER_PROXY']    
  end

  after(:all) do
    FileUtils.rm_rf XmlResolution::ResolverCollection.data_path
  end

  def test_proxy
    ENV['RESOLVER_PROXY']
  end

  def example_mets_document
    File.read(File.join(File.dirname(__FILE__), 'files', 'example-xml-documents', 'F20060215_AAAAHL.xml'))
  end

  # this fellow doesn't get anything resolved:

  def another_example_mets_document
    File.read(File.join(File.dirname(__FILE__), 'files', 'example-xml-documents', 'E20090705_AAAAMG-1905070401.xml'))
  end

  def yet_another_example_mets_document
    File.read(File.join(File.dirname(__FILE__), 'files', 'example-xml-documents', 'UF00056159_00002.xml'))
  end

  def collection_one 
    'E20101010_DEFACE'
  end

  def collection_two
    'foo-bar'
  end

  def collection_three
    'spa ces'
  end

  it "should fail when we've not initialized the data path" do
    lambda { XmlResolution::ResolverCollection.new(collection_one) }.should raise_error(XmlResolution::CollectionInitializationError)
  end

  it "should allow us to specify the data_path and retrieve it" do

    path = Dir.mktmpdir 
    lambda { XmlResolution::ResolverCollection.data_path = path }.should_not raise_error
    XmlResolution::ResolverCollection.data_path.should == path
  end

  it "should tell us that a badly named collection id is invalid" do
        XmlResolution::ResolverCollection.collection_name_ok?('bad name').should == false
        XmlResolution::ResolverCollection.collection_name_ok?('good-name').should == true
        XmlResolution::ResolverCollection.collection_name_ok?('bad/name').should == false
  end

  it "should throw an exception when a badly named collection id is used in a constructor" do
    lambda { XmlResolution::ResolverCollection.new('bad name') }.should raise_error XmlResolution::CollectionNameError
  end

  it "should initially give us an empty list of collections" do
    XmlResolution::ResolverCollection.collections.length.should == 0
  end

  it "should allow us to create a collection" do
    lambda { XmlResolution::ResolverCollection.new(collection_one) }.should_not raise_error
  end

  it "should allow us to specify the creation of a collection a second time with the same name" do
    lambda { XmlResolution::ResolverCollection.new(collection_one) }.should_not raise_error
  end


  it "should allow us to get the last_modified time of a collection" do
    xrez = XmlResolution::ResolverCollection.new(collection_one)
    (Time.now - xrez.last_modified).should be_close(0, 2)
  end


  it "should allow us to retrieve a list of collections" do
    list = XmlResolution::ResolverCollection.collections
    list.length.should == 1
    list.include?(collection_one).should == true
  end

  it "should allow us to add a new collection and retrieve the updated list of collections" do
    XmlResolution::ResolverCollection.new(collection_two)

    list = XmlResolution::ResolverCollection.collections
    list.length.should == 2
    list.include?(collection_one).should == true
    list.include?(collection_two).should == true
  end

  it "should allow us to direclty determine if a collection exists" do
    XmlResolution::ResolverCollection.collection_exists?(collection_two).should == true
    XmlResolution::ResolverCollection.collection_exists?('bogus_collection').should == false
  end

  it "should allow us to retrieve the schemas directory from an object" do
    col = XmlResolution::ResolverCollection.new(collection_one)
    File.directory?(col.schema_path).should == true 
  end

  it "should allow us to retrieve the collections directory from an object" do
    col = XmlResolution::ResolverCollection.new(collection_one)
    File.directory?(col.collection_path).should == true 
    (col.collection_path =~ /#{collection_one}$/).should > 0
  end

  it "should allow us to add an XmlResolver object" do
    col  = XmlResolution::ResolverCollection.new collection_one
    xrez = XmlResolution::XmlResolver.new example_mets_document, test_proxy

    lambda { col.add xrez }.should_not raise_error
  end

  it "should allow us to add an already added XmlResolver object, and it should tell us where it is stored." do
    rc   = XmlResolution::ResolverCollection.new collection_one
    xrez = XmlResolution::XmlResolver.new example_mets_document, test_proxy
    xrez.filename = 'example-mets-document.xml'

    xrez.local_uri.should == nil
    lambda { rc.add xrez }.should_not raise_error
    xrez.local_uri.should_not == nil
  end

  it "should allow us to add a second and third XmlResolver object, and it should tell us where *they* is stored." do
    rc   = XmlResolution::ResolverCollection.new collection_one

    xrez = XmlResolution::XmlResolver.new another_example_mets_document, test_proxy
    xrez.filename = 'another-example-mets-document.xml'

    xrez.local_uri.should == nil
    lambda { rc.add xrez }.should_not raise_error
    xrez.local_uri.should_not == nil

    xrez = XmlResolution::XmlResolver.new yet_another_example_mets_document, test_proxy
    xrez.filename = 'yet-another-example-mets-document.xml'

    xrez.local_uri.should == nil
    lambda { rc.add xrez }.should_not raise_error
    xrez.local_uri.should_not == nil
  end


  it "should produce a manifest file" do
    rc   = XmlResolution::ResolverCollection.new collection_one
    data = nil
    rc.manifest { |pathname| data = File.read(pathname) }
    data.length.should > 1024
    (data =~ /<resolutions\s+/).should_not == nil
    (data =~ /<resolution\s+/).should_not == nil
    (data =~ /<schema status="success"\s+/).should_not == nil
  end

  it "should produce a tar file of our files, with a manifest" do
    rc   = XmlResolution::ResolverCollection.new collection_one
    temp = Tempfile.new(collection_one + '-tar')
    rc.tar temp
    toc = `tar -tvf #{temp.path}`
    (toc =~ /#{File.join(collection_one, 'manifest.xml')}/).should_not == nil
    (toc =~ /http:\/\/www.fcla.edu\/dls\/md\/daitss\/daitss.xsd/).should_not == nil
  end

end
