require 'timeout'
require 'uri'
require 'xmlresolution/exceptions'

module ResolverUtils

  # Timeout in seconds for the read_lock and write_lock methods.

  LOCK_TIMEOUT = 10

  # user [ PATHNAME ]
  #
  # Without argument, return the name (a string) of the user running
  # this process.  With argument PATHNAME (a string) naming an
  # existing, readable file, return the user name who owns it.

  def ResolverUtils.user pathname = nil
    if pathname.nil?
      Etc.getpwuid(Process.uid).name
    else
      Etc.getpwuid(File.stat(pathname).uid).name
    end
  end

  # group [ PATHNAME ]
  #
  # Without argument, return the group name (a string) of the user
  # running this process.  With argument PATHNAME (a string) naming an
  # existing readable file, return its group name.

  def ResolverUtils.group pathname = nil
    if pathname.nil?
      Etc.getgrgid(Process.gid).name
    else
      Etc.getgrgid(File.stat(pathname).uid).name
    end
  end

  # check_directory PHRASE, DIRECTORY
  #
  # Carefully check that DIRECTORY is writable, and if not, throwing an XmlResolution::ConfigurationError
  # with a helpful, descriptive message, preceded by PHRASE (e.g. "The FooBar storage directory")

  def ResolverUtils.check_directory phrase, directory

    if not File.exists? directory
      raise XmlResolution::ConfigurationError, "#{phrase} #{directory} doesn't exist or is unreadble by this user (#{ResolverUtils.user}) and group (#{ResolverUtils.group})."
    end

    if not File.directory? directory
      raise XmlResolution::ConfigurationError, "#{phrase} #{directory} isn't a directory."
    end

    if not File.readable? directory
      raise XmlResolution::ConfigurationError, "#{phrase} #{directory} isn't readable by this user (#{ResolverUtils.user}) or group (#{ResolverUtils.group})."
    end

    if not File.writable? directory
      raise XmlResolution::ConfigurationError, "#{phrase} #{directory} isn't writable by this user (#{ResolverUtils.user}) or group (#{ResolverUtils.group})."
    end
  end

  # write_lock FILEPATH
  #
  # Access the file FILEPATH exclusively. Times out after LOCK_TIMEOUT
  # seconds, raising a LockError exception.  On successfully obtaining
  # a lock we truncate the file, and yield a file descriptor ready for
  # writing.  On return the file is properly closed. See the
  # description of write_lock for more details on how these kinds of
  # lock work.

  def ResolverUtils.write_lock filepath
    open(filepath, 'w') do |fd|
      Timeout.timeout(LOCK_TIMEOUT) { fd.flock(File::LOCK_EX) }
      yield fd
    end
  rescue Timeout::Error => e
    raise XmlResolution::LockError, "Timed out waiting #{LOCK_TIMEOUT} seconds for write lock to #{filepath}: #{e.message}"
  end

  # read_lock FILEPATH
  #
  # Access the file FILEPATH in a shared manner.  Note that we have
  # two kinds of locks associated with a given file, read_locks and
  # write_locks.  There may be 0, 1 or many locks active at any
  # time. There may exist many active read_locks at once, but if there
  # is an active write_lock, it is the only lock of any kind in
  # existance at that time.  Requests for locks may block for up to
  # LOCK_TIMEOUT seconds, after which a LockError exception is raised.
  #
  # On success, we yield a file desciptor positioned at the
  # beginning of the file and ready to read from.  On return, the
  # file is properly closed.

  def ResolverUtils.read_lock filepath
    open(filepath, 'r') do |fd|
      Timeout.timeout(LOCK_TIMEOUT) { fd.flock(File::LOCK_SH) }
      yield fd
    end
  rescue Timeout::Error => e
    raise XmlResolution::LockError, "Timed out waiting #{LOCK_TIMEOUT} seconds for read lock to #{filepath}: #{e.message}"
  end

  # escape *LIST
  #
  # Given the arugment list LIST of strings, first URI escape them, then join them with a space and
  # return the constructed string.

  def ResolverUtils.escape *list
    list.map{ |elt| URI.escape(elt) }.join(' ')
  end

  # unescape STRING 
  #
  # Perform the inverse of the escape method.

  def ResolverUtils.unescape string
    data = string.split(/\s+/)
    data.map{ |elt| URI.unescape(elt) }
  end

  # collection_name_ok? COLLECTION_ID
  #
  # A boolean to determine if the string COLLECTION_ID is a valid
  # collection id. It has to fit into the filesystem as a directory,
  # so must be a single path component.
  #
  # Note that the top-level routes can be more restrictive about
  # collection names - for instance, a UUID or IEID.

  def ResolverUtils.collection_name_ok? collection_id
    not (collection_id =~ /\// or collection_id != URI.escape(collection_id))
  end

end # of module


