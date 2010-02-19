require 'tmpdir'

require 'xmlresolution/rc'
require 'xmlresolution/exceptions'

describe XmlResolution::Rc do

  before(:all) do 
    
  end

  after(:all) do
    FileUtils.rm_rf XmlResolution::Rc.data_path
  end

  def collection_one 
    'E20101010_DEFACE'
  end

  def collection_two
    'foo bar'
  end

  it "should fail when we've not initialized the data path" do
    lambda { XmlResolution::Rc.new(collection_one) }.should raise_error(XmlResolution::CollectionInitializationError)
  end

  it "should allow us to specify the data_path and retrieve it" do
    path = Dir.mktmpdir 
    lambda { XmlResolution::Rc.data_path = path }.should_not raise_error
    XmlResolution::Rc.data_path.should == path
  end

  it "should initially give us an empty list of collections" do
    XmlResolution::Rc.collections.length.should == 0
  end

  it "should allow us to create a collection" do
    lambda { XmlResolution::Rc.new(collection_one) }.should_not raise_error
  end

  it "should allow us to specify the creation of a collection a second time with the same name" do
    lambda { XmlResolution::Rc.new(collection_one) }.should_not raise_error
  end


  it "should allow us to retrieve a list of collections" do
    list = XmlResolution::Rc.collections
    list.length.should == 1
    list.include?(collection_one).should == true
  end

  it "should allow us to add a new collection and retrieve the updated list of collections" do
    XmlResolution::Rc.new(collection_two)

    list = XmlResolution::Rc.collections
    list.length.should == 2
    list.include?(collection_one).should == true
    list.include?(collection_two).should == true
  end

  it "should allow us to retrieve the schemas directory" do
    col = XmlResolution::Rc.new(collection_one)
    File.directory?(col.schema_path).should == true 
  end

  it "should allow us to retrieve the collections directory" do
    col = XmlResolution::Rc.new(collection_one)
    File.directory?(col.collection_path).should == true 
    (col.collection_path =~ /#{collection_one}$/).should > 0

  end

end
