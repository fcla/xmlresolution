require 'xmlresolution/utils'

describe XmlResolution do

  it "should provide version label information" do
    (XmlResolution.version.label =~ %r{^\d+\.\d+\.\d+$}).should == 0
  end

  it "should provide version uri information" do
    (XmlResolution.version.uri =~ %r{^info:fcla/daitss/xmlresolution}).should == 0
  end

  it "should provide version note information" do
    (XmlResolution.version.uri =~ %r{[a-zA-z0-9]+}).should_not == nil
  end

  it "should escape and concanate a list of strings" do
    XmlResolution.escape('th is', 'is', 'a', 'test').should == 'th%20is is a test'
  end

  it "should unescape a string into an array" do
    XmlResolution.unescape('th%20is is a test')[0].should == 'th is'
  end

end
  
