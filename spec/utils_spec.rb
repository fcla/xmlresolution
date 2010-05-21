require 'xmlresolution/utils'
require 'tempfile'

describe ResolverUtils do

  it "should escape and concanate a list of strings" do
    ResolverUtils.escape('th is', 'is', 'a', 'test').should == 'th%20is is a test'
  end

  it "should unescape a string into an array" do
    ResolverUtils.unescape('th%20is is a test').length.should == 4
    ResolverUtils.unescape('th%20is is a test')[0].should == 'th is'
  end

  it "should report collection id names with / or blanks as invalid" do
    ResolverUtils.collection_name_ok?("foo/bar").should ==  false
    ResolverUtils.collection_name_ok?("foo bar").should ==  false
    ResolverUtils.collection_name_ok?("foobar").should ==  true
  end

  it "should get the owner of this process" do
    ResolverUtils.user.should == `whoami`.chomp
  end

  it "should get the owner of this file" do
    ResolverUtils.user(__FILE__).should == `whoami`.chomp
  end

  it "should get the group of this process" do
    ResolverUtils.group.should == `id -gn`.chomp
  end

  it "should get the group of this file" do
    ResolverUtils.group(__FILE__).should == `id -gn`.chomp
  end

  it "should raise an error on a non-writable directory" do
    lambda { ResolverUtils.check_directory("oops", "/etc/") }.should raise_error XmlResolution::ConfigurationError
  end

  it "should not raise an error on a writable directory" do
    lambda { ResolverUtils.check_directory("well, ok", ".") }.should_not raise_error
  end

  it "should be able to get two read locks on a file" do
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

  it "should allow a write_lock to be obtained on an existing file, and new file contents to be written" do
    tempfile = Tempfile.new('lock-', '/tmp')
    tempfile.write "A failed test."
    tempfile.close
    ResolverUtils.write_lock(tempfile.path) do |fd|
      fd.write "A successful test."
    end
    tempfile.open.read.should == "A successful test."
  end

  it "should allow a write_lock to be obtained on a non-existing file, creating it, and new file contents to be written" do

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


  it "should not be able to get a write lock, or modify a file, after a read lock is established" do
    tempfile = Tempfile.new('lock-', '/tmp')
    tempfile.write 'A test.'
    tempfile.close
    lambda { write_lock_denied_test(tempfile.path) }.should raise_error XmlResolution::LockError
    tempfile.open.read.should == 'A test.'
  end


end
  
