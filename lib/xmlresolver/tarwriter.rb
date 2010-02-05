  # Author: Randy Fischer (rf@ufl.edu) for DAITSS
  #
  # This class allows us to write tar files on the fly from a list of 
  # filenames.
  #
  # Once we have the tar-writer object, we use the write method to
  # write out tar'd files, one by one.  No directories are allowed,
  # only plain files. The existing file permissions and mtimes of the
  # tar'd files are used in the tar files; however, we can set our own
  # file names internally in the tar, and we always use the permissions
  # specified in the initialization of the TarWriter object.
  # 
  # Usage:
  #
  #   tr = TarWriter.new(STDOUT, { :uid => 80, :gid => 80, :username => 'daitss', :groupname => 'daitss' })
  #
  #   tr.write '/etc/passwd', 'bar/passwd'
  #   tr.write '/etc/group', 'bar/group'
  #   tr.close
  #
  # Running the above program:
  #
  #   ruby tarwriter-example | tar tvf -
  #
  # Produces:
  #
  #   -rw-r--r--  0 daitss daitss   3667 Jun 23 02:19 bar/passwd
  #   -rw-r--r--  0 daitss daitss   1682 Sep 20 13:23 bar/group
  #


class TarWriter

  # TODO: instead of an explicit file descriptor, why not yield up the tar file
  # in larger chunks....

  # TODO: we could use a simpler tar format than the one I'm using - I modeled this on 
  # bsdtar 2.6.2 (mac os x) - use recent version of gnutar instead....


  # A hash having keys :uid, :gif, :username, :groupname, used to set permissions for all
  # files included in the tar file we produce.

  attr_reader :ownership

  # A file descriptor we will write to.  It could be a StringIO object, if you really want to
  # get a string out of this class.

  attr_reader :fd

  # Create a object that will allow us to stream a tar file to given file
  # descriptor FD.  The second argument FILE_OWNERSHIP, a hash, gives
  # the :gid, :uid, :username and :groupname to use for all files.

  def initialize fd, file_ownership
    [:gid, :uid, :username, :groupname].each { |key| raise "Missing required file ownership key #{key}." unless file_ownership[key] }
    @ownership   = file_ownership
    @fd          = fd
  end

  private

  # Format INT as octal string, optionally prefix with leading zeros to fill out to PAD length.
  # INT may be a string or fixnum.

  def to_octal int, pad = nil
    pad ? sprintf("%0#{pad}o", int) : sprintf('%o', int)
  end

  # Determine the checksum of a header BUFF.  The location of the
  # checksum itself (at buff[148..155]) is treated as a string of
  # blanks.

  def header_checksum buff
    sum =  0
    (0   .. 147).each { |i| sum += buff[i] }
    (156 .. 511).each { |i| sum += buff[i] }
    sum + 32 * 8   
  end

  # Build a boilerplate header based on what we know won't change: for us, that's
  # plain files on plain filesystems with a global set of ownership 

  def standard_header
    buff = 0.chr * 512

    # uid/gid:  6 octal characters followed by space

    buff[108..114] = to_octal(ownership[:uid], 6) + ' '
    buff[116..122] = to_octal(ownership[:gid], 6) + ' '

    # type of file: we only use regular files here, thanks!

    buff[156..156] = '0'

    # magic

    buff[257..261] = 'ustar'

    # ustar version

    buff[263..264] = '00'

    # device major and minor numbers

    buff[329..335]  = '000000 '
    buff[337..343]  = '000000 '

    # username and group name

    str = ownership[:username][0..31]
    buff[265..(265 + str.length - 1)] = str

    str = ownership[:groupname][0..31]
    buff[297..(297 + str.length - 1)] = str 


    return buff
  end
      
  # Given the string FILE_PATH to a file and the string TARFILE_PATH, the pathname to use for the tar entry,
  # create a header for the file.

  def make_header file_path, tarfile_path

    fstat = File::stat(file_path)
    buff  = standard_header()

    # Set file-dependent headers

    # Filename - left justified in position 0..99
    # we try to fix up overlong file name, try to leave something useful

    filename = tarfile_path[0..100]
    filename.gsub(/\/+$/, '')

    buff[0..(filename.length-1)] = filename

    # file mode: 6 octal characters plus space. Note that fstat gives us the filetype anded into the high bits

    buff[100..106] = '000' + fstat.mode.to_s(8)[3..5] + ' '

    # mtime of file - epoch time format, in octal, followed by a space

    buff[136..147] = fstat.mtime.to_i.to_s(8) + ' '

    # size of file - we only use the short file size encoding - 11 octal characters, left padded with zeros, followed by a space

    buff[124..135] = to_octal(fstat.size, 11) + ' '    

    # now that all of the header is setup, we can compute the checksum:

    str = '0' + to_octal(header_checksum(buff))
    buff[148..(148 + str.length - 1)] = str

    return buff
  end


  public

  # Write out a tar header for the file found at FILE_PATH, using the TAR_PATH string as the 
  # filename in the tar file.  If TAR_PATH is not supplied, initialize from FILE_PATH, removing
  # leading slashes.

  def write file_path, tar_path = nil

    length = nil

    tar_path = file_path.gsub(/^\/+/, '') unless tar_path

    fd.write make_header(file_path, tar_path)    
    open(file_path, 'r') do |file|
      while buff = file.read(512)
        fd.write buff
        length = buff.length
      end
    end
    
    fd.write 0.chr * (512 - length)   # pad with nul characters to 512 bytes, if necessary.
  end

  # Write two 512-byte blocks of nul characters to end the tar file.

  def close
    fd.write 0.chr * 1024
    fd.close
  end  
end
