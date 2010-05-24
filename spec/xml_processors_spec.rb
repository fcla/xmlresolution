require 'xmlresolution/xml_processors'
require 'tmpdir'
require 'tempfile'
require 'fileutils'
require 'nokogiri'

describe PlainXmlDocument do

  @@files = File.join(File.dirname(__FILE__), 'files', 'example-xml-documents')

  def daitss_instance_doc
    File.read(File.join(@@files, 'UF00056159_00002.xml'))
  end

  it "should allow us to initialize and process an instance XML document without arguments" do
    doc = PlainXmlDocument.new
    Nokogiri::XML::SAX::Parser.new(doc).parse(daitss_instance_doc)
    doc.errors.count.should == 0
  end

  it "should find the version in an instance XML document" do
    doc = PlainXmlDocument.new
    Nokogiri::XML::SAX::Parser.new(doc).parse(daitss_instance_doc)
    doc.version.should == '1.0'
  end

  it "should find the namespaces in an instance XML" do
    doc = PlainXmlDocument.new
    Nokogiri::XML::SAX::Parser.new(doc).parse(daitss_instance_doc)
    doc.used_namespaces["http://www.loc.gov/METS/"].should == true
    doc.used_namespaces["http://www.loc.gov/mods/v3"].should == true
    doc.used_namespaces["http://www.uflib.ufl.edu/digital/metadata/ufdc2/"].should == true
    doc.used_namespaces["http://www.w3.org/2001/XMLSchema-instance"].should == true
    doc.used_namespaces["http://www.w3.org/1999/xlink"].should == true
    doc.used_namespaces["http://www.fcla.edu/dls/md/daitss/"].should == true
  end

  it "should allow us to initialize with namespace hash argument, augmenting the hash after processing" do
    ns = { 'http://www.loc.gov/mods/v3' => true }
    doc = PlainXmlDocument.new(ns)
    Nokogiri::XML::SAX::Parser.new(doc).parse(daitss_instance_doc)
    ns["http://www.loc.gov/METS/"].should == true
    ns["http://www.loc.gov/mods/v3"].should == true
    ns["http://www.uflib.ufl.edu/digital/metadata/ufdc2/"].should == true
    ns["http://www.w3.org/2001/XMLSchema-instance"].should == true
    ns["http://www.w3.org/1999/xlink"].should == true
    ns["http://www.fcla.edu/dls/md/daitss/"].should == true
  end


  it "should provide the locations of the used namespaces in an XML document" do
    doc = PlainXmlDocument.new
    Nokogiri::XML::SAX::Parser.new(doc).parse(daitss_instance_doc)

    locs = doc.namespace_locations

    locs['http://www.loc.gov/standards/mets/mets.xsd'].should                == 'http://www.loc.gov/METS/'
    locs['http://www.loc.gov/mods/v3/mods-3-3.xsd'].should                   == 'http://www.loc.gov/mods/v3'
    locs['http://www.fcla.edu/dls/md/daitss/daitss.xsd'].should              == 'http://www.fcla.edu/dls/md/daitss/'
    locs['http://www.uflib.ufl.edu/digital/metadata/ufdc2/ufdc2.xsd'].should == 'http://www.uflib.ufl.edu/digital/metadata/ufdc2/'
  end

  it "should find the errors in an XML document" do
    text = daitss_instance_doc.gsub('</METS:mets>', '< </METS:mets>')
    doc = PlainXmlDocument.new
    Nokogiri::XML::SAX::Parser.new(doc).parse(text)
    doc.errors.count.should == 1
  end
end # of PlainXmlDocument


describe SchemaDocument do

  @@files = File.join(File.dirname(__FILE__), 'files', 'example-xml-documents')

  def daitss_xsd_text
    File.read(File.join(@@files, 'daitss.xsd'))
  end
  
  def daitss_xsd_location
    'http://www.fcla.edu/dls/md/daitss/daitss.xsd'
  end

  def mods_xsd_text
    File.read(File.join(@@files, 'mods-3-0.xsd'))
  end

  def mods_xsd_location
    'http://www.loc.gov/standards/mods/v3/mods-3-0.xsd'
  end

  it "should allow us to initialize and process a Schema (DAITSS) that uses includes, detecting relevant additional namespaces" do
    doc = SchemaDocument.new(daitss_xsd_location, {})
    Nokogiri::XML::SAX::Parser.new(doc).parse(daitss_xsd_text)

    doc.errors.count.should == 0
    doc.used_namespaces.keys.count.should == 4

    doc.used_namespaces["http://www.fcla.edu/dls/md/daitss/"].should        == true
    doc.used_namespaces["http://www.w3.org/2001/XMLSchema"].should          == true
    doc.used_namespaces["http://www.w3.org/2001/XMLSchema-instance"].should == true
    doc.used_namespaces["http://www.w3.org/XML/1998/namespace"].should      == true
  end
  
  it "should allow us to process a Schema (DAITSS) that uses includes, find all the relevant locations needed for further processing" do
    doc = SchemaDocument.new(daitss_xsd_location, {})
    Nokogiri::XML::SAX::Parser.new(doc).parse(daitss_xsd_text)

    locations = doc.namespace_locations

    locations["http://www.fcla.edu/dls/md/daitss/daitssAccount.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssAccountProject.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssActionPlan.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssAdmin.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssAgreementInfo.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssArchiveLogic.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssAviFile.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBilling.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBitstream.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBitstreamBsProfile.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsAudio.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsAudioWave.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsImage.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsImageJpeg.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsImageJpeg2000.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsImageTiff.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsMarkup.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsPdf.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsPdfAction.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsPdfAnnotation.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsPdfFilter.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsProfile.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsTable.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsText.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsTextCSV.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssBsVideo.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssCompression.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssContact.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssDataFile.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssDataFileFormatAttribute.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssDataFileSevereElement.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssDistributed.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssDocumentLocation.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssEvent.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssFormat.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssFormatAttribute.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssFormatSpecification.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssGlobalFile.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssIntEntity.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssIntEntityGlobalFile.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssMediaType.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssMessageDigest.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssMessageDigestType.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssOutputRequest.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssPdfAction.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssPdfAnnotation.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssPdfFilter.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssProject.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssQuickTimeFile.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssRelationship.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssReport.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssSevereElement.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssSeverity.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssSpecification.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssStorageDesc.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssStorageDescPrep.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssStorageInstance.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssStoragePrep.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssSubAccount.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssSupportingSpecification.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.fcla.edu/dls/md/daitss/daitssWaveFile.xsd"].should == "http://www.fcla.edu/dls/md/daitss/"
    locations["http://www.w3.org/2001/XMLSchema.xsd"].should == "http://www.w3.org/2001/XMLSchema"        
  end

  it "should allow us to initialize and process a Schema (MODS) that uses imports, getting only the relevant additional namespaces" do
    doc = SchemaDocument.new(mods_xsd_location, {})
    Nokogiri::XML::SAX::Parser.new(doc).parse(mods_xsd_text)
    doc.errors.count.should == 0
    doc.used_namespaces.keys.count.should == 4
    doc.used_namespaces["http://www.loc.gov/mods/v3"].should           == true
    doc.used_namespaces["http://www.w3.org/1999/xlink"].should         == true
    doc.used_namespaces["http://www.w3.org/2001/XMLSchema"].should     == true
    doc.used_namespaces["http://www.w3.org/XML/1998/namespace"].should == true
  end
  
  it "should allow us to initialize and process a Schema (MODS) that uses imports, find all the relevant locations needed for further processing" do

    doc = SchemaDocument.new(mods_xsd_location, {})
    Nokogiri::XML::SAX::Parser.new(doc).parse(mods_xsd_text)

    locations = doc.namespace_locations

    locations.keys.count.should == 2
    locations["http://www.loc.gov/standards/mods/xlink.xsd"].should == "http://www.w3.org/1999/xlink"
    locations["http://www.w3.org/2001/xml.xsd"].should              == "http://www.w3.org/XML/1998/namespace"

  end
  

end # of SchemaDocument
