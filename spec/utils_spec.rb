require 'xmlresolution/utils'
require 'xmlresolution/exceptions'
require 'tempfile'

describe XmlResolution::ConfigurationError do  # this lets us cover the class hierarchy

  it "should allow us to extract a client-message from a low-level application exception" do
    ex = nil
    begin
      raise XmlResolution::ConfigurationError, 'this is a test'
    rescue => ex
    end
    (ex.client_message =~ /500 Internal Service Error - this is a test/).should_not == nil
  end
end


describe ResolverUtils do

  it "should escape and concatenate a list of strings into one string" do
    ResolverUtils.escape('th is', 'is', 'a', 'test').should == 'th%20is is a test'
  end

  it "should unescape a previously escaped string into an array" do
    ResolverUtils.unescape('th%20is is a test').length.should == 4
    ResolverUtils.unescape('th%20is is a test')[0].should == 'th is'
  end

  it "should report collection id names with / or blanks as invalid when checking a collection name" do
    ResolverUtils.collection_name_ok?("foo/bar").should ==  false
    ResolverUtils.collection_name_ok?("foo bar").should ==  false
    ResolverUtils.collection_name_ok?("foobar").should  ==  true
  end

  it "should get the owner of this process with the user utilitiy" do
    ResolverUtils.user.should == `whoami`.chomp
  end

  it "should get the owner of this file with the user utility" do
    ResolverUtils.user(__FILE__).should == `whoami`.chomp
  end

  it "should get the group of this process with the group utility" do
    ResolverUtils.group.should == `id -gn`.chomp
  end

  it "should get the group of a file with the group utility" do
    begin
      tempfile = Tempfile.new('group-check-')
      tempfile.write 'foo'
      tempfile.close
      ResolverUtils.group(tempfile.path).should == `id -gn`.chomp
    ensure
      tempfile.unlink
    end
  end

  it "should raise an error if a plain file is used when doing a directory check" do
    lambda { ResolverUtils.check_directory("oops", "/etc/passwd") }.should raise_error XmlResolution::ConfigurationError
  end

  it "should raise an error if a non-existant path is used when doing a directory check" do
    lambda { ResolverUtils.check_directory("oops", "/foo/bar/") }.should raise_error XmlResolution::ConfigurationError
  end

  it "should raise an error if an unreadable path is sent for a directory check" do

    unreadable_dir = case RUBY_PLATFORM
                     when /linux/   ; '/lost+found'
                     when /darwin/  ; '/audit'
                     else ; raise "Unhandled platform #{RUBY_PLATFORM}"
                     end
    lambda { ResolverUtils.check_directory("oops", unreadable_dir) }.should raise_error XmlResolution::ConfigurationError
  end

  it "should raise an error on a non-writable directory when doing a directory check" do
    lambda { ResolverUtils.check_directory("oops", "/etc/") }.should raise_error XmlResolution::ConfigurationError
  end

  it "should not raise an error on a writable directory when doing a directory check" do
    lambda { ResolverUtils.check_directory("well, ok", ".") }.should_not raise_error
  end

  it "should allow us to get two read locks on a file" do
    f1 = ''
    f2 = ''
    ResolverUtils.read_lock(__FILE__) do |fd1|
      f1 = fd1.read
      ResolverUtils.read_lock(__FILE__) do |fd2|
        f2 = fd2.read
      end
    end
    f1.should == f2
  end

  it "should be allow us to obtain a write_lock for an existing file, so that new file writes over the previous contents" do
    tempfile = Tempfile.new('lock-', '/tmp')
    tempfile.write "A failed test."
    tempfile.close
    ResolverUtils.write_lock(tempfile.path) do |fd|
      fd.write "A successful test."
    end
    tempfile.open.read.should == "A successful test."
  end

  it "should  allow us to obtain a write_lock on a non-existing file, creating it, and allow writes to it" do

    tempfile = Tempfile.new('lock-', '/tmp')  # create a new file and delete it.
    tempfile.close
    path = tempfile.path
    tempfile.unlink
    
    File.exists?(path).should == false

    ResolverUtils.write_lock(path) do |fd|
      fd.write "A successful test."
    end
    open(path).read.should == "A successful test."
  end

      def write_lock_denied_test path
        ResolverUtils.read_lock(path, 3) do |fd1|
          f1 = fd1.read
          ResolverUtils.write_lock(path, 0.25) do |fd2|
            fd2.write 'error condition'
          end
        end 
      end

  it "should not allow the creation of a write lock, nor modify the contents of a file, after a read lock is established" do
    tempfile = Tempfile.new('lock-', '/tmp')
    tempfile.write 'A test.'
    tempfile.close
    lambda { write_lock_denied_test(tempfile.path) }.should raise_error XmlResolution::LockError
    tempfile.open.read.should == 'A test.'
  end

      def read_lock_denied_test path, contents
        ResolverUtils.write_lock(path, 3) do |fd1|
          fd1.write contents
          ResolverUtils.read_lock(path, 0.25) do |fd2|
             raise fd2.read
          end
        end 
      end

  it "should not allow the creation of a read lock, nor modify the contents of a file, after a write lock is established" do
    tempfile = Tempfile.new('lock-', '/tmp')
    tempfile.write 'A test.'
    tempfile.close
    lambda { read_lock_denied_test(tempfile.path, 'Another test.') }.should raise_error XmlResolution::LockError
    tempfile.open.read.should == 'Another test.'
  end


  it "should return a hostname from a numeric address using the remote_name method, if reverse DNS pointers exist" do
    name = ResolverUtils.remote_name "128.227.228.113"  # darchive's address
    name.should == "fclnx30.fcla.edu"
  end

  it "should return the original numeric address using the remote_name method, if reverse DNS pointers do not exist" do
    name = ResolverUtils.remote_name "128.227.228.0"  
    name.should == "128.227.228.0"
  end


end
  
