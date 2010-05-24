require 'digest/md5'
require 'fileutils'
require 'nokogiri'
require 'socket'
require 'tempfile'
require 'tmpdir'
require 'tmpdir'
require 'xmlresolution/xml_resolver'
require 'xmlresolution'                   # required for version.

include XmlResolution

describe XmlResolver do  # and XmlResolverReloaded

  @@files = File.join(File.dirname(__FILE__), 'files', 'example-xml-documents')
  @@store = nil
  @@resvoler = nil
  @@enough_already = nil
  @@collection_id = 'E19561201_HIBABE'

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
             when /sacred.net/;      'satyagraha.sacred.net:3128'
             when /romeo-foxtrot/;   'localhost:3128'
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

  it "should recursively process an XML document" do
    file_name = daitss_instance_doc
    file_text = File.read file_name
    lambda { @@resolver = XmlResolver.new(file_text, file_url(file_name), store, proxy) }.should_not raise_error
  end

  it "should properly record the instance document and its relevant metadata" do

    text = File.read(daitss_instance_doc)

    @@resolver.document_text.should == text
    @@resolver.document_size.should == text.length
    @@resolver.document_identifier.should == Digest::MD5.hexdigest(text)

  end

  it "should not have any unresolved namespaces for our sample DAITSS descriptor XML file." do
    @@resolver.unresolved_namespaces.should == []
  end

  it "should not correctly locate and download the 77 schemas our sample DAITSS descriptor XML file requires." do

    # need to have the following locations downloaded from our resolution (keep this list sorted)

    required_successes = [ 
                 "http://www.fcla.edu/dls/md/daitss/daitss.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssAccount.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssAccountProject.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssActionPlan.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssAdmin.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssAgreementInfo.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssArchiveLogic.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssAviFile.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBilling.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBitstream.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBitstreamBsProfile.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBoolean.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsAudio.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsAudioWave.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsImage.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsImageJpeg.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsImageJpeg2000.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsImageTiff.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsMarkup.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsPdf.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsPdfAction.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsPdfAnnotation.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsPdfFilter.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsProfile.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsTable.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsText.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsTextCSV.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssBsVideo.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssCompression.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssContact.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssDataFile.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssDataFileFormatAttribute.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssDataFileSevereElement.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssDataTypes.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssDate.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssDistributed.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssDocumentLocation.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssEnum.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssEvent.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssFormat.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssFormatAttribute.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssFormatSpecification.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssGlobalFile.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssIntEntity.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssIntEntityGlobalFile.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssMediaType.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssMessageDigest.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssMessageDigestType.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssNumber.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssOutputRequest.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssPdfAction.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssPdfAnnotation.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssPdfFilter.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssProject.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssQuickTimeFile.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssRelationship.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssReport.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssSevereElement.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssSeverity.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssSpecification.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssStorageDesc.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssStorageDescPrep.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssStorageInstance.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssStoragePrep.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssString.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssSubAccount.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssSupportingSpecification.xsd",
                 "http://www.fcla.edu/dls/md/daitss/daitssWaveFile.xsd",
                 "http://www.loc.gov/standards/mets/mets.xsd",
                 "http://www.loc.gov/standards/mods/v3/mods-3-3.xsd",
                 "http://www.loc.gov/standards/mods/xml.xsd",
                 "http://www.loc.gov/standards/xlink/xlink.xsd",
                 "http://www.uflib.ufl.edu/digital/metadata/ufdc2/ufdc2.xsd",
                 "http://www.w3.org/2001/XMLSchema.xsd",
                 "http://www.w3.org/2001/xml.xsd",
                ]
    
    required_redirects =  [ 
                  "http://www.loc.gov/mods/v3/mods-3-3.xsd",
                  "http://www.loc.gov/mods/xml.xsd" 
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

    success_results.sort!
    failure_results.sort!
    redirect_results.sort!
    unknown_results.sort!
    
    success_results.should == required_successes
    redirect_results.should == required_redirects
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

  
  it "should have no errors on the resolution of our DAITSS descriptor XML." do
    @@resolver.errors.count.should == 0
  end

  it "should be able to save resolution data and reload it." do

    id = @@resolver.document_identifier

    @@resolver.save(@@collection_id)
    @@reloaded = XmlResolverReloaded.new(@@store, @@collection_id, id)

    original = @@resolver.schema_dictionary.sort { |a,b| a.location.downcase <=> b.location.downcase }
    reloaded  = @@reloaded.schema_dictionary.sort { |a,b| a.location.downcase <=> b.location.downcase }
    
    original.length.should == reloaded.length
    
    (0..original.length-1).each do |i|
      [:location, :localpath, :namespace, :last_modified, :digest, :retrieval_status, :error_message, :redirected_location].each do |method|
        original[i].send(method).should == reloaded[i].send(method)
      end
    end
  end
  
end # of XmlResolver and XmlResolverReloaded

