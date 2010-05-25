require 'xmlresolution/resolver_collection'
require 'xmlresolution/xml_resolver'
require 'socket'
require 'tempfile'

include XmlResolution

describe ResolverCollection do

  @@store = nil
  @@files = File.join(File.dirname(__FILE__), 'files', 'example-xml-documents')

  def proxy 
    prox = ENV['RESOLVER_PROXY']
    prox ||= case hostname
             when /romeo-foxtrot/;   'localhost:3128'
             when /sacred.net/;      'satyagraha.sacred.net:3128'
             when /fcla.edu/;        'sake.fcla.edu'
             else
               nil
             end
    
    if prox.nil? and not @@enough_already
      @@enough_already = true
      STDERR.puts 'No http proxy set: will download schemas directly - very slow.  Set environment variable RESOLVER_PROXY to caching proxy if you want to speed this up.'
    end
    prox
  end

  def hostname 
    Socket.gethostname
  end

  def file_url name
    "file://#{hostname}/" + name.gsub(%r{^/+}, '')
  end

  def daitss_instance_doc
    File.join(@@files, 'UF00056159_00002.xml')
  end

  def mets_instance_doc
    File.join(@@files, 'F20060215_AAAAHL.xml')
  end

  def snwf_instance_doc
    File.join(@@files, 'SNWF000003.xml')
  end


  def collection_name_1
    'E20100524_ZODIAC'
  end

  def collection_name_2
    'E19561201_ZYGOTE'
  end

  before(:all) do 
    @@store = Dir.mktmpdir('resolver-store-', '/tmp')
    FileUtils.mkdir_p File.join(@@store, 'schemas')
    FileUtils.mkdir_p File.join(@@store, 'collections')
  end

  after(:all) do
    FileUtils::rm_rf @@store
  end

  it "should create new collections" do
    ResolverCollection.new(@@store, collection_name_1)
    ResolverCollection.new(@@store, collection_name_2)

    ResolverCollection.collections(@@store).include?(collection_name_1).should == true
    ResolverCollection.collections(@@store).include?(collection_name_2).should == true
  end

  it "should save document resolution data" do
    mets_resolver   = XmlResolver.new(File.read(mets_instance_doc),   file_url(mets_instance_doc),   @@store, proxy)
    daitss_resolver = XmlResolver.new(File.read(daitss_instance_doc), file_url(daitss_instance_doc), @@store, proxy)
    snwf_resolver   = XmlResolver.new(File.read(snwf_instance_doc),   file_url(snwf_instance_doc),   @@store, proxy)

    mets_resolver.save(collection_name_1)
    daitss_resolver.save(collection_name_1)
    snwf_resolver.save(collection_name_1)

    collection = ResolverCollection.new(@@store, collection_name_1)

    doc_ids = collection.resolutions.map { |resolver| resolver.document_identifier }

    collection.resolutions.count.should == 3
    doc_ids.include?(mets_resolver.document_identifier).should   == true
    doc_ids.include?(daitss_resolver.document_identifier).should == true
    doc_ids.include?(snwf_resolver.document_identifier).should   == true
  end

  it "should give the collapsed list of schemas" do

    collection = ResolverCollection.new(@@store, collection_name_1)

    collection.resolutions.count.should == 3

    # Create a uniquified list of all of the downloaded schemas... around 77 of them

    schema_locs = {}
    collection.resolutions.each do |resolver|
      list = resolver.schema_dictionary.map{ |rec| rec.location if rec.retrieval_status == :success  }.compact
      list.each { |loc| schema_locs[loc] = true }
    end
    locations = schema_locs.keys.sort { |a,b| a.downcase <=> b.downcase }
    
    locations.count.should > 70
    locations.count.should < 100
    
    # Make sure all the successfully downloaded schemas in the resolution objects are listed somewhere in the manifest:

    manifest = collection.manifest

    locations.each { |loc|  /#{loc}/.should =~ manifest }

    # Create a tarfile of the schemas; get a table of contents of the tar'd output of the collection using a third-party
    # tar program; make sure the 
    
    tmp = Tempfile.new('tar-', '/tmp')
    collection.tar do |io|
      tmp.write io.read
    end
    tmp.close
    tar_toc = `tar tvf #{tmp.path}`
    tmp.unlink

    %r{#{collection.collection_name}/manifest\.xml}.should =~ tar_toc

    locations.each { |loc|  %r{#{collection.collection_name}/#{loc}}.should =~ tar_toc }
  end

  
  # tar, resolutions, manifest


end # ResolverCollection




