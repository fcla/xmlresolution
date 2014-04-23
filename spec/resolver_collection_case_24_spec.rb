# encoding: UTF-8
warn_level = $VERBOSE
$VERBOSE = nil 
require 'xmlresolution/resolver_collection'
require 'xmlresolution/xml_resolver'
require 'socket'
require 'tempfile'
#
#
#tests frick.xml and frack.xml.  They point to md5 identical dtd's but differenct locations
# this test ensures that there are two seperate dtd's that get downloaded because they are from different locations
#  the manifest has the correct md5 for the two dtd's
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

  def frick_instance_doc
    File.join(@@files, 'frick.xml')
  end

  def frack_instance_doc
    File.join(@@files, 'frack.xml')
  end



  def collection_name_1
    'DUPLICATE_DTD_S'
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
    frack_resolver   = XmlResolver.new(File.read(frack_instance_doc),   file_url(frack_instance_doc),   @@store, proxy)
    frick_resolver = XmlResolver.new(File.read(frick_instance_doc), file_url(frick_instance_doc), @@store, proxy)

    # save the data collected to our collection

    frack_resolver.save(collection_name_1)
    frick_resolver.save(collection_name_1)

    # Let's get the collection:

    collection = ResolverCollection.new(@@store, collection_name_1)

    # look through the resolutions in the collection: grab the document identifiers in doc_ids

    doc_ids = collection.resolutions.map { |resolver| resolver.document_identifier }

    # do we have all three we expect? (check for the document identifiers we've saved)

    collection.resolutions.count.should == 2
    doc_ids.include?(frack_resolver.document_identifier).should   == true
    doc_ids.include?(frick_resolver.document_identifier).should == true
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
    #  
    locations.count.should > 1  # 70
    locations.count.should < 3  # 100
    
    # Make sure all the successfully downloaded schemas in the resolution objects are listed somewhere in the manifest:

    manifest = collection.manifest

    manifest.index('<dtd status="success" location="http://schema.fcla.edu/xml/frick_1fec8a9a5ba1ea5922ba81ff590b4422.dtd" md5="1fec8a9a5ba1ea5922ba81ff590b4422"').should_not == nil

    manifest.index('<dtd status="success" location="http://schema.fcla.edu/xml/frack_1fec8a9a5ba1ea5922ba81ff590b4422.dtd" md5="1fec8a9a5ba1ea5922ba81ff590b4422"').should_not == nil

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




