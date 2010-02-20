require 'tmpdir'

require 'xmlresolution/resolvercollection'
require 'xmlresolution/exceptions'

describe XmlResolution::ResolverCollection do

  before(:all) do 
    
  end

  after(:all) do
    FileUtils.rm_rf XmlResolution::ResolverCollection.data_path
  end

  def collection_one 
    'E20101010_DEFACE'
  end

  def collection_two
    'foo bar'
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

  it "should initially give us an empty list of collections" do
    XmlResolution::ResolverCollection.collections.length.should == 0
  end

  it "should allow us to create a collection" do
    lambda { XmlResolution::ResolverCollection.new(collection_one) }.should_not raise_error
  end

  it "should allow us to specify the creation of a collection a second time with the same name" do
    lambda { XmlResolution::ResolverCollection.new(collection_one) }.should_not raise_error
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

  it "should allow us to determine if a collection exists" do
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

end
