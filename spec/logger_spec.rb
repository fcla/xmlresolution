require 'tempfile'
require 'xmlresolution/logger'

include XmlResolution

describe Logger do

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
    lambda { Logger.info 'testing...', env  }.should raise_error
  end

  it "should allow initialization to a file" do
    lambda { Logger.filename = logfile.path }.should_not raise_error
  end

  it "should allow writing an informational message" do
    msg = "This is an informational test"
    Logger.info msg, env
    (read_logfile =~ /^\s+INFO.*#{msg}/m).should_not == nil
  end

  it "should allow writing a warning message" do
    msg = "This is a warning test"
    Logger.warn msg, env
    (read_logfile =~ /^\s*WARN.*#{msg}/m).should_not == nil
  end

  it "should allow writing an error message" do
    msg = "This is an error test"
    Logger.err msg, env
    (read_logfile =~ /^\s*ERR.*#{msg}/m).should_not == nil
  end

  it "should allow us to instantiate an object" do
    lambda { Logger.new }.should_not raise_error
  end

  it "should allow us to write using the object" do
    logger = Logger.new 
    msg = "This is an object lesson for rack::commonlogger"
    logger.write msg
    (read_logfile =~ /^\s*INFO.*#{msg}/m).should_not == nil
  end
end
