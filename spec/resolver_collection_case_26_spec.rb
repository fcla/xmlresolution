# encoding: UTF-8
warn_level = $VERBOSE
$VERBOSE = nil 
require 'xmlresolution/resolver_collection'
require 'xmlresolution/xml_resolver'
require 'socket'
require 'tempfile'
#
#
#tests same schema contents different locations, should get same md5 in manifest
# http://schema.fcla.edu/xml/daitss_one_a2aa0a4a13503457317d2a94a4e8b038.xsd==  refered in TestCase26.xml
# http://schema.fcla.edu/xml/daitss_two_a2aa0a4a13503457317d2a94a4e8b038.xsd    refered in aip.xml
#


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
    File.join(@@files, 'aip.xml')
  end

  def daitss_instance_doc2
    File.join(@@files, 'TestCase26.xml')
  end


  def content_doc3
    File.join(@@files, 'hasOnlyPi.xml')
  end


  def collection_name_1
    'DUPLICATE_XSD_S'
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

    ResolverCollection.collections(@@store).include?(collection_name_1).should == true
  end

  it "should save document resolution data" do

    # resolve three representative documents:
    daitss_resolver2   = XmlResolver.new(File.read(daitss_instance_doc2),   file_url(daitss_instance_doc2),   @@store, proxy)
    daitss_resolver = XmlResolver.new(File.read(daitss_instance_doc), file_url(daitss_instance_doc), @@store, proxy)

    # save the data collected to our collection

    daitss_resolver2.save(collection_name_1)
    daitss_resolver.save(collection_name_1)

    # Let's get the collection:

    collection = ResolverCollection.new(@@store, collection_name_1)

    # look through the resolutions in the collection: grab the document identifiers in doc_ids

    doc_ids = collection.resolutions.map { |resolver| resolver.document_identifier }

    # do we have all three we expect? (check for the document identifiers we've saved)

    collection.resolutions.count.should == 2
    doc_ids.include?(daitss_resolver2.document_identifier).should   == true
    doc_ids.include?(daitss_resolver.document_identifier).should == true
  end

  it "should give the collapsed list of schemas" do
    # get the collection of resolutions we've created:
    collection = ResolverCollection.new(@@store, collection_name_1)

    collection.resolutions.count.should == 2

    # Create a uniquified list of all of the downloaded schemas... we
    # expect around 16 of them (lots of repeated schemas over the
    # four  document resolutions):

    schema_locs = {}
    collection.resolutions.each do |resolver|
      list = resolver.schema_dictionary.map{ |rec| rec.location if rec.retrieval_status == :success  }.compact
      list.each { |loc| schema_locs[loc] = true }
    end
    locations = schema_locs.keys.sort { |a,b| a.downcase <=> b.downcase }
    # as 20120712  the exact number was 16
    locations.count.should > 7  # 70
    locations.count.should < 9  # 100
    
    # Make sure all the successfully downloaded schemas in the resolution objects are listed somewhere in the manifest:

    manifest = collection.manifest

    manifest.index('<schema status="success" namespace="http://www.fcla.edu/dls/md/daitss/" location="http://schema.fcla.edu/xml/daitss_one_a2aa0a4a13503457317d2a94a4e8b038.xsd" md5="a2aa0a4a13503457317d2a94a4e8b038') || 
    manifest.index('<schema status="success" location="http://schema.fcla.edu/xml/daitss_one_a2aa0a4a13503457317d2a94a4e8b038.xsd" namespace="http://www.fcla.edu/dls/md/daitss/" md5="a2aa0a4a13503457317d2a94a4e8b038')
    .should_not == nil


    manifest.index('<schema status="success" namespace="http://www.fcla.edu/dls/md/daitss/" location="http://schema.fcla.edu/xml/daitss_two_a2aa0a4a13503457317d2a94a4e8b038.xsd" md5="a2aa0a4a13503457317d2a94a4e8b038') ||
    manifest.index('<schema status="success" location="http://schema.fcla.edu/xml/daitss_two_a2aa0a4a13503457317d2a94a4e8b038.xsd" namespace="http://www.fcla.edu/dls/md/daitss/" md5="a2aa0a4a13503457317d2a94a4e8b038"').should_not == nil

    locations.each { |loc|  /#{loc}/.should =~ manifest }

    # Create a tarfile of the schemas; get a table of contents of the tar'd output of the collection using a third-party
    # tar program:
    
    tmp = Tempfile.new('tar-', '/tmp')
    collection.tar do |io|
      tmp.write io.read
    end
    tmp.close
    tar_toc = `tar tvf #{tmp.path}`
    tmp.unlink

    # Do we have a manifest in the tar file?

    %r{#{collection.collection_name}/manifest\.xml}.should =~ tar_toc

    # Is each of the locations we found represented in the tar file?

    locations.each do |loc| 
      tar_entry = "#{collection.collection_name}/#{loc}".sub('http://', 'http/')
      %r{#{tar_entry}}.should =~ tar_toc
    end
  end

end # ResolverCollection




