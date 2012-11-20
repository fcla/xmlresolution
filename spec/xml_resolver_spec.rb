require 'digest/md5'
require 'fileutils'
require 'nokogiri'
require 'socket'
require 'tempfile'
require 'tmpdir'
require 'tmpdir'
require 'xmlresolution/xml_resolver'
require 'xmlresolution'                   # required for version.

$KCODE = 'UTF8'

include XmlResolution

describe XmlResolver do  # and XmlResolverReloaded

  @@files          = File.join(File.dirname(__FILE__), 'files', 'example-xml-documents')
  @@store          = nil
  @@resvoler       = nil
  @@enough_already = nil
  @@collection_id  = 'E19561201_HIBABE'

  before(:all) do
    @@store = Dir.mktmpdir('resolver-store-', '/tmp')
    FileUtils.mkdir_p File.join(@@store, 'schemas')
    FileUtils.mkdir_p File.join(@@store, 'collections')
    FileUtils.mkdir_p File.join(@@store, 'collections', @@collection_id)
  end

  after(:all) do
    FileUtils::rm_rf @@store
  end

  def hostname
    Socket.gethostname
  end

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

  def store
    @@store
  end

  def file_url name
    "file://#{hostname}/" + name.gsub(%r{^/+}, '')
  end

  def daitss_instance_doc
    File.join(@@files, 'UF00056159_00002.xml')
  end

  it "should recursively process an XML document." do
    file_name = daitss_instance_doc
    file_text = File.read file_name
    #lambda { @@resolver = XmlResolver.new(file_text, file_url(file_name), store, proxy) }.should_not raise_error
    lambda { @@resolver = XmlResolver.new(file_text, file_name, store, proxy) }.should_not raise_error    # github issue 14:w
  end

  it "should properly record the instance document and its relevant metadata." do

    text = File.read(daitss_instance_doc)
    @@resolver.document_text.should == text
    @@resolver.document_size.should == text.length
    @@resolver.document_identifier.should == Digest::MD5.hexdigest(text)   #github issue #14
    ##############@@resolver.document_identifier.should == Digest::MD5.hexdigest(daitss_instance_doc)  # github issue 14
    # @@resolver.resolution_time.should be_close(Time.now, 30)
    @@resolver.resolution_time.should be_within(30).of(Time.now)
  end

  it "should not have only UFLIB's unresolved namespace for our sample DAITSS descriptor XML file." do
    @@resolver.unresolved_namespaces.should == ['http://digital.uflib.ufl.edu/metadata/ufdc2/']
  end

  it "should have a few unresolved namespaces for our example normalized file descriptor." do

    name = File.join(@@files, "F20060402_AAAAAB_NORM.xml")
    text = File.read(name)
    res  = XmlResolver.new(text, file_url(name), store, proxy)

    res.fatal.should == false
    res.unresolved_namespaces.sort.should == ["http://www.w3.org/2001/XMLSchema", "http://www.w3.org/XML/1998/namespace"]

  end


  it "should show a fatal error for resolving a binary file" do
  begin
    name = File.join(@@files, "binary.xml")
    text = File.read(name)
    res  = XmlResolver.new(text, file_url(name), store, proxy)
  rescue
    #res.fatal.should == true
    #res.premis_report.should =~ %r{<error>Start tag expected, '&lt;' not found</error>}
    baddoc = $!.instance_of? XmlResolution::BadXmlDocument
    baddoc.should == true
  end
  end


  it "should correctly locate and download the 77 schemas our sample DAITSS descriptor XML file requires." do

    # need to have the following locations downloaded from our resolution (keep this list sorted); this
    # used the DAITSS validation tool to get what a standard XML validator would retrieve.

    required_successes = ["http://digital.uflib.ufl.edu/metadata/ufdc2/ufdc2.xsd",
	                  "http://www.fcla.edu/dls/md/daitss/daitss.xsd",
			  "http://www.loc.gov/standards/mets/mets.xsd",
			  "http://www.loc.gov/standards/mods/v3/mods-3-3.xsd",
			  "http://www.loc.gov/standards/mods/xml.xsd",
			  "http://www.loc.gov/standards/xlink/xlink.xsd",
			  "http://www.w3.org/2001/XMLSchema.xsd",
			  "http://www.w3.org/2001/xml.xsd"
                         ]

    # these next are likely to change over time:

    required_redirects =  [
                           "http://www.loc.gov/mods/v3/mods-3-3.xsd",
                           "http://www.loc.gov/mods/xml.xsd",
                           "http://www.uflib.ufl.edu/digital/metadata/ufdc2/ufdc2.xsd"
                          ]

    success_results  = []
    failure_results  = []
    redirect_results = []
    unknown_results  = []

    @@resolver.schema_dictionary.each do |our_result|

      case our_result.retrieval_status
      when :success
        success_results.push  our_result.location
        File.exists?(our_result.localpath).should == true
      when :failure
        failure_results.push  our_result.location
      when :redirect
        redirect_results.push our_result.location
      else
        unknown_results.push our_result.location
      end
    end


    success_results.sort.should  == required_successes
    redirect_results.sort.should == required_redirects

    failure_results.should == []
    unknown_results.should == []
  end

  it "should produce a PREMIS document describing the resolution." do
    premis = @@resolver.premis_report
    (premis =~ /^<premis.*>.*<\/premis>$/mi).should_not == nil
    (premis =~ /<agent.*>.*<\/agent>/mi).should_not == nil
    (premis =~ /<event.*>.*<\/event>/mi).should_not == nil
    (premis =~ /<object.*>.*<\/object>/mi).should_not == nil
  end

  it "should have no errors when performing the resolution of our DAITSS descriptor XML." do
    @@resolver.errors.count.should == 0
  end

  it "should be able to save resolution data and reload it." do

    id = @@resolver.document_identifier

    @@resolver.save(@@collection_id)
    @@reloaded = XmlResolverReloaded.new(@@store, @@collection_id, id)

    original = @@resolver.schema_dictionary.sort { |a,b| a.location.downcase <=> b.location.downcase }
    reloaded = @@reloaded.schema_dictionary.sort { |a,b| a.location.downcase <=> b.location.downcase }

    original.length.should == reloaded.length

    (0..original.length-1).each do |i|
      [:location, :localpath, :namespace, :last_modified, :digest, :retrieval_status, :error_message, :redirected_location].each do |method|
        original[i].send(method).should == reloaded[i].send(method)
      end
    end
  end

end # of XmlResolver and XmlResolverReloaded

