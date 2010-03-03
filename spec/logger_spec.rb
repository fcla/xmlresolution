require 'tempfile'
require 'xmlresolution/logger'

describe XmlResolution::Logger do

  @@tmpfile = nil

  def logfile   # return a tempfile path to write to 
    @@tmpfile ||= Tempfile.new('xmlresolution-spec-log', '/tmp')
  end

  def read_logfile
    logfile.open.read
  end

  def env
    Hash.new
  end

  it "should throw an exception if it has not been initialized" do
    lambda { XmlResolution::Logger.info 'testing...', env  }.should raise_error
  end

  it "should allow initialization to a file" do
    lambda { XmlResolution::Logger.filename = logfile.path }.should_not raise_error
  end

  it "should allow writing an informational message" do
    msg = "This is an informational test"
    XmlResolution::Logger.info msg, env
    (read_logfile =~ /^\s+INFO.*#{msg}/m).should_not == nil
  end

  it "should include a timestamp in apache format, e.g. [01/Dec/2009:11:19:09]" do
    (read_logfile =~ /\[\d+\/(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\/\d{4}(:\d\d){3}\]/).should_not == nil
  end

  it "should allow writing a warning message" do
    msg = "This is a warning test"
    XmlResolution::Logger.warn msg, env
    (read_logfile =~ /^\s*WARN.*#{msg}/m).should_not == nil
  end

  it "should allow writing an error message" do
    msg = "This is an error test"
    XmlResolution::Logger.err msg, env
    (read_logfile =~ /^\s*ERR.*#{msg}/m).should_not == nil
  end

  it "should allow us to instantiate an object" do
    lambda { XmlResolution::Logger.new }.should_not raise_error
  end

  it "should allow us to write using the object" do
    logger = XmlResolution::Logger.new 
    msg = "This is an object lesson for rack::commonlogger"
    logger.write msg
    (read_logfile =~ /^\s*INFO.*#{msg}/m).should_not == nil
  end
end
