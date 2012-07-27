require 'digest/md5'
require 'fileutils'
require 'socket'
require 'tmpdir'
require 'xmlresolution/schema_catalog'

include XmlResolution

describe SchemaCatalog do

  @@tempdir = nil 
  @@proxy   = nil
  @@catalog = nil

  def proxy 
    prox = ENV['RESOLVER_PROXY']
    prox ||= case Socket.gethostname
             when /iterman/;   'localhost:3128'
             when /romeo-foxtrot/;   'localhost:3128'
             when /sacred.net/;      'satyagraha.sacred.net:3128'
             when /fcla.edu/;        'sake.fcla.edu'
             else
               nil
             end
    
    if prox.nil?
      STDERR.puts 'No http proxy set: will download schemas directly - very slow.  Set environment variable RESOLVER_PROXY to caching proxy if you want to speed this up.'
    end
    prox
  end


  before(:all) do 
    @@tempdir = Dir.mktmpdir('schema-catalog-test-', '/tmp') + '/'
    @@proxy   = proxy
  end

  after(:all) do

    FileUtils.rm_rf @@tempdir
  end

  def daitss_namespace_locations
    { 'http://www.fcla.edu/dls/md/daitss/daitss.xsd' => 'http://www.fcla.edu/dls/md/daitss/' }
    #{ 'http://localhost/daitss.xsd' => 'http://www.fcla.edu/dls/md/daitss/' }
  end

  # we'll get a redirect with this one.

  it "should refuse to initialize without a writable directory" do
    locs = daitss_namespace_locations
    lambda{ cat = SchemaCatalog.new(locs, '/etc/') }.should raise_error
  end

  it "should retrieve the datiss schema directly from our website" do
    @@catalog = SchemaCatalog.new(daitss_namespace_locations, @@tempdir, @@proxy)
    recs = @@catalog.schemas 
    recs.length.should == 1
    info = recs[0]
    info.retrieval_status.should == :success
    File.exists?(info.localpath).should == true
    #Digest::MD5.hexdigest(File.read(info.localpath)).should == info.digest
    Digest::MD5.hexdigest(info.location).should == info.digest   #  github issue  14
    
  end

  it "should merge additional records, retrieving those schema" do
    @@catalog.merge({ 'http://www.fcla.edu/dls/md/daitss/1.16/daitssAdmin.xsd' => 'http://www.fcla.edu/dls/md/daitss/admin/' }) #.merge({ 'http://www.fcla.edu/dls/md/daitss/daitssBitstream.xsd' => 'http://www.fcla.edu/dls/md/daitss/' })
    recs = @@catalog.schemas
    recs.length.should == 2

    recs.each do |info|
      info.retrieval_status.should == :success
      File.exists?(info.localpath).should == true
      Digest::MD5.hexdigest(info.location).should == info.digest
    end
  end

  it "should not merge additional records if they've already been retrieved" do

    #@@catalog.merge({ 'http://www.fcla.edu/dls/md/daitss/daitssBitstream.xsd' => 'http://www.fcla.edu/dls/md/daitss/' })
    @@catalog.merge({ 'http://www.fcla.edu/dls/md/daitss/1.16/daitssAdmin.xsd' => 'http://www.fcla.edu/dls/md/daitss/admin/' })
    recs = @@catalog.schemas
    recs.length.should == 2
  end

  it "should retrieve the mods schema, performing the necessary redirect" do
    
    # currently, http://www.loc.gov/mods/v3/mods-3-2.xsd causes a redirect
    # to http://www.loc.gov/standards/mods/v3/mods-3-2.xsd

    ns  = 'http://www.loc.gov/mods/v3'
    loc = 'http://www.loc.gov/mods/v3/mods-3-2.xsd'

    @@catalog.merge({ loc  => ns })
    recs = @@catalog.schemas

    recs.length.should == 4   # adds one redirect record, one for the direct retrieval

    info = nil
    recs.each { |rec| info = rec if rec.namespace == ns and rec.location == loc }  # find the redirect record
    
    info.should_not == nil

    if info
      info.retrieval_status.should    == :redirect
      info.redirected_location.should == 'http://www.loc.gov/standards/mods/v3/mods-3-2.xsd'
    end
  end

  it "should retrieve the schema location information from the catalog via a block method" do
    locs = []
    successes = 0
    failures  = 0
    redirects = 0

    @@catalog.schemas do |rec|
      locs.push rec.location
      case rec.retrieval_status
      when :success;  successes += 1
      when :failure;  failures  += 1
      when :redirect; redirects += 1
      end
    end

    locs.length.should == 4
    locs.include?("http://www.fcla.edu/dls/md/daitss/daitss.xsd").should == true
    locs.include?("http://www.fcla.edu/dls/md/daitss/1.16/daitssAdmin.xsd").should == true
    locs.include?("http://www.loc.gov/mods/v3/mods-3-2.xsd").should == true
    locs.include?("http://www.loc.gov/standards/mods/v3/mods-3-2.xsd").should == true

    successes.should == 3
    redirects.should == 1
    failures.should  == 0
  end

  it "should add an error record if the location is unfetchable" do

    badloc = 'http://www.fcla.edu/dls/md/daitss/daitssFooBar.xsd'
    @@catalog.merge({ badloc => 'http://www.fcla.edu/dls/md/daitss/' })

    errec = nil
    @@catalog.schemas.each { |rec| errec = rec if rec.location == badloc }

    errec.should_not == nil
    if not errec.nil?
      errec.retrieval_status.should == :failure
      (errec.error_message =~ /404/).should_not == nil
    end

  end

  it "should allow subsequent catalogs to reuse the same data" do    # this forces some additional coverage in the class.
    catalog = SchemaCatalog.new(daitss_namespace_locations, @@tempdir, @@proxy)
    recs = catalog.schemas 
    recs.length.should == 1
  end


end # of tests
