require 'digest/md5'
require 'fileutils'
require 'tmpdir'
require 'xmlresolution/schema_catalog'

include XmlResolution

describe SchemaCatalog do

  @@tempdir = Dir.mktmpdir('schema-catalog-test-', '/tmp') + '/'
  @@proxy   = nil
  @@cat     = nil

  before(:all) do 
    @@proxy = ENV['RESOLVER_PROXY']   # set this environment variable if you want to test via a proxy
  end

  after(:all) do
    FileUtils.rm_rf @@tempdir
  end

  def daitss_namespace_locations
    { 'http://www.fcla.edu/dls/md/daitss/daitss.xsd' => 'http://www.fcla.edu/dls/md/daitss/' }
  end

  # we'll get a redirect with this one.

  it "should refuse to initialize without a writable directory" do
    locs = daitss_namespace_locations
    lambda{ cat = SchemaCatalog.new(locs, '/etc/') }.should raise_error
  end

  it "should retrieve the datiss schema directly from our website" do
    @@cat = SchemaCatalog.new(daitss_namespace_locations, @@tempdir, @@proxy)
    recs = @@cat.schemas 
    recs.length.should == 1
    info = recs[0]
    info.retrieval_status.should == :success
    File.exists?(info.localpath).should == true
    Digest::MD5.hexdigest(File.read(info.localpath)).should == info.digest
  end

  it "should merge additional records, retrieving those schema" do

    @@cat.merge({ 'http://www.fcla.edu/dls/md/daitss/daitssBitstream.xsd' => 'http://www.fcla.edu/dls/md/daitss/' })
    recs = @@cat.schemas
    recs.length.should == 2

    recs.each do |info|
      info.retrieval_status.should == :success
      File.exists?(info.localpath).should == true
      Digest::MD5.hexdigest(File.read(info.localpath)).should == info.digest
    end
  end

  it "should retrieve the mods schema, performing the necessary redirect" do
    
    # currently, http://www.loc.gov/mods/v3/mods-3-2.xsd causes a redirect
    # to http://www.loc.gov/standards/mods/v3/mods-3-2.xsd

    ns  = 'http://www.loc.gov/mods/v3'
    loc = 'http://www.loc.gov/mods/v3/mods-3-2.xsd'

    @@cat.merge({ loc  => ns })
    recs = @@cat.schemas

    recs.length.should == 4   # adds one redirect record, one for the direct retrieval

    info = nil
    recs.each { |rec| info = rec if rec.namespace == ns and rec.location == loc }  # find the redirect record
    
    info.should_not                 == nil
    info.retrieval_status.should    == :redirect
    info.redirected_location.should == 'http://www.loc.gov/standards/mods/v3/mods-3-2.xsd'
  end



end # of tests
