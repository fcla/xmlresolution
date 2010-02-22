require 'xmlresolution/tarwriter'
require 'tmpdir'
require 'tempfile'
require 'fileutils'

describe XmlResolution::TarWriter do

  @@dir = nil
  @@tarfile = nil

  before do
    @@dir = some_directory
    @@tarfile = Tempfile.new('tf')
  end

  after do
    FileUtils::rm_rf @@dir    
    FileUtils::rm_f "/tmp/passwd"
  end

  # list_tar  - use the system tar to list the files in our tar; we expect something like this:
  #
  # -rw-------  0 daitss-user daitss-group 3376 Nov 13 15:25 tmp/tar-test-1353/tf20091113-1353-keexjq-0
  #
  # perms/dunno/user/group/size/mon/day/time/file
  # 0     1     2    3    4     5   6   7    8

  def list_tar 
    `tar tvf #{@@tarfile.path}`.split("\n")
  end

  def some_directory
   FileUtils.mkdir("/tmp/tar-test-#{$$}")
  end

  def some_data
    text = ''
    (0..99).each do |line|
      text += "Some test data, line #{line}: " + rand(100000000).to_s + "\n"
    end
    text
  end

  def some_filepath
    path = nil
    Tempfile.open('tf', @@dir) do |fl| 
      fl.puts some_data
      path = fl.path
    end
    path
  end

  it "should create a tarwriter object" do
    XmlResolution::TarWriter.new(@@tarfile, { :gid => 80, :uid => 80, :username => 'daitss', :groupname => 'daitss' }).class.to_s == 'XmlResolution::TarWriter'
  end

  it "should store files consectively in a tarfile" do

    tf = XmlResolution::TarWriter.new(@@tarfile, { :gid => 80, :uid => 80, :username => 'daitss', :groupname => 'daitss' })

    tf.write(some_filepath)
    tf.write(some_filepath)
    tf.write(some_filepath)
    tf.close

    lines = list_tar
    lines.length.should == 3
  end


  it "should save files by their filename correctly in a tarfile" do

    tf = XmlResolution::TarWriter.new(@@tarfile, { :gid => 80, :uid => 80, :username => 'daitss', :groupname => 'daitss' })

    filepath = some_filepath
    tf.write(filepath)
    tf.close

    first_line = list_tar[0]

    tarname = first_line.split[8]
    filepath.should == "/" + tarname   # gnutar strips the leading "/" in the TOC
  end


  it "should save files by our specified path in a tarfile" do

    tf = XmlResolution::TarWriter.new(@@tarfile, { :gid => 80, :uid => 80, :username => 'daitss', :groupname => 'daitss' })

    filepath = some_filepath
    tf.write(filepath, 'myfile')
    tf.close

    first_line = list_tar[0]
    tarname    = first_line.split[8]

    tarname.should == 'myfile'
  end


  it "should save files with the correct user and group names in a tarfile" do

    tf = XmlResolution::TarWriter.new(@@tarfile, { :gid => 80, :uid => 80, :username => 'daitss-user', :groupname => 'daitss-group' })

    filepath = some_filepath
    tf.write(filepath)
    tf.close

    first_line = list_tar[0]
    first_line.split[2].should == 'daitss-user'
    first_line.split[3].should == 'daitss-group'
  end


  it "should provide a file that gnutar can correctly extract, retaining the file metadata" do

    tf = XmlResolution::TarWriter.new(@@tarfile, { :gid => 80, :uid => 80, :username => 'daitss-user', :groupname => 'daitss-group' })
    tf.write("/etc/passwd", "/tmp/passwd")
    tf.close

    `tar xPf #{@@tarfile.path}`

    orig  = File.stat("/etc/passwd")
    copy  = File.stat("/tmp/passwd")

    copy.mode.should  == orig.mode
    copy.size.should  == orig.size
    copy.mtime.should == orig.mtime
    copy.atime.should == orig.atime
  end

  
end
