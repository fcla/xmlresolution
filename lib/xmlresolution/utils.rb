require 'socket'
require 'timeout'
require 'uri'
require 'xmlresolution/exceptions'

# ResolverUtils provides a service class of useful methods for the
# XmlResolution service.

module ResolverUtils

  # Timeout in seconds for the read_lock and write_lock methods.

  LOCK_TIMEOUT = 10

  # user [ PATHNAME ]
  #
  # Without argument, return the name (a string) of the user running
  # this process.  With argument PATHNAME (a string) naming an
  # existing, readable file, return the name of the user who owns it.

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
      Etc.getgrgid(File.stat(pathname).gid).name
    end
  end

  # check_directory PHRASE, DIRECTORY
  #
  # Carefully check that the directory named by the string DIRECTORY
  # is writable, and if not, throw an
  # XmlResolution::ConfigurationError with a descriptive message
  # preceded by PHRASE.

  def ResolverUtils.check_directory phrase, directory

    if not File.exists? directory
      raise XmlResolution::ConfigurationError, "#{phrase} #{directory} doesn't exist or is unreadable by this user (#{ResolverUtils.user}) and group (#{ResolverUtils.group})."
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

  # write_lock FILEPATH [ WAIT_TIME = LOCK_TIMEOUT ]
  #
  # Access the file named by FILEPATH exclusively. FILEPATH does not
  # have to exist. Times out after LOCK_TIMEOUT (or the optional
  # WAIT_TIME, if specified) seconds, raising a LockError exception.
  # On successfully obtaining a lock we truncate the file, and yield a
  # file descriptor ready for writing.  On exiting the block the file
  # is properly closed and the lock released. See the description of
  # read_lock for more details on how these kinds of lock work.

  def ResolverUtils.write_lock filepath, wait_time = LOCK_TIMEOUT
    open(filepath, 'a+') do |fd|                                # 'a+' followed by truncate in body; with just 'w' in
      Timeout.timeout(wait_time) { fd.flock(File::LOCK_EX) }    #  open we truncate w/o getting a lock!
      fd.truncate(0)
      yield fd
    end
  rescue Timeout::Error => e
    raise XmlResolution::LockError, "Timed out waiting #{wait_time} seconds for write lock to #{filepath}: #{e.message}"
  end

  # read_lock FILEPATH [ WAIT_TIME = LOCK_TIMEOUT ]
  #
  # Access the file named by FILEPATH in a shared manner.  Note that
  # we have two kinds of locks associated with a given file,
  # read_locks and write_locks.  There may be 0, 1 or many locks
  # active at any time. There may exist many active read_locks at
  # once, but if there is an active write_lock, it is the only lock of
  # any kind in existance (for FILEPATH) at that time.  Requests for
  # locks may block for up to WAIT_TIME seconds (defaults to
  # LOCK_TIMEOUT), after which a LockError exception is raised.
  #
  # On success, we yield a file desciptor positioned at the beginning
  # of the file and ready to read from.  On exiting the block, the
  # file is properly closed and the lock released.

  def ResolverUtils.read_lock filepath, wait_time = LOCK_TIMEOUT
    open(filepath, 'r') do |fd|
      Timeout.timeout(wait_time) { fd.flock(File::LOCK_SH) }
      yield fd
    end
  rescue Timeout::Error => e
    raise XmlResolution::LockError, "Timed out waiting #{wait_time} seconds for read lock to #{filepath}: #{e.message}"
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
  # and must be able to server as a single path component.
  #
  # Note that the top-level routes can and should be more restrictive
  # about collection names - for instance, a UUID or IEID.

  def ResolverUtils.collection_name_ok? collection_id
    not (collection_id =~ /\// or collection_id != URI.escape(collection_id))
  end

  # remote_name ADDR
  #
  # Attempts a reverse lookup on IP address ADDR; if it fails, just returns the
  # original address ADDR.

  def ResolverUtils.remote_name addr
    return addr if addr.nil? or addr !~ /^(\d+\.){3}\d+$/
    Socket.gethostbyaddr(addr.split('.').map{ |octet| octet.to_i }.pack('CCCC'))[0]
  rescue => e
    addr
  end

  Struct.new('StartUpConfig',
             :data_root,
             :log_syslog_facility,
             :resolver_proxy,
             :virtual_hostname
             )

  def ResolverUtils.read_config yaml_file

    conf = Struct::StartUpConfig.new

    begin
      hash = YAML::load(File.open(yaml_file))
    rescue => e
      raise "Can't parse the XML Resolution service configuration file '#{yaml_file}': #{e.message}."
    else
      raise "Can't parse the data in the XML Resolution service configuration file '#{yaml_file}'." if hash.class != Hash
    end

    conf.members.each { |x| conf[x] = hash[x] }

    # reasonable defaults

    conf.virtual_hostname ||= Socket.gethostname
    conf.data_root        ||= File.expand_path(File.join(File.dirname(__FILE__), 'data'))

    return conf
  end


end # of module


