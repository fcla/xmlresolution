require 'xmlresolution'

# xmlresolution.rb mostly just includes the actual library files, but there
# is a version class method in it; we test those here.

describe XmlResolution do

  it "should provide a VERSION constant" do
    (XmlResolution::VERSION =~ /^1\./).should == 0
  end

  it "should provide a RELEASE constant" do
    (XmlResolution::RELEASE.length > 0).should == true
  end

  it "should provie a REVISION constant" do
    (XmlResolution::REVISION.length > 0).should == true
  end


  it "should provide a to_s method on version that matches the version label information" do
    ("#{XmlResolution.version}" =~ /^XML Resolution Service Version 1\./).should == 0
  end

  it "should provide version rev information" do
    (XmlResolution.version.rev =~ %r{^Version}).should_not == nil
  end

  it "should provide version uri information" do
    (XmlResolution.version.uri =~ %r{^info:fcla/daitss/xmlresolution}).should == 0
  end
  

end
  
