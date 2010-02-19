# TODO: Appropriate to do logging in this class?  
# TODO: Should a general resolution failure percolate up an exception that can result in 400 error?

require 'digest/md5'
require 'fileutils'
require 'uri'
require 'builder'
require 'time'        # brings in parse & iso8601 methods for Time objects
require 'tempfile'
require 'xmlresolution/xmlresolver' #
require 'xmlresolution/tarwriter'   # lets us build tar files on the fly

# This class stores and retrieves information for XmlResolution
# service.  It maintains a set of collection identifiers supplied by
# the calling program, and certain resolution_data for files with that
# collection id.  That resolution_data includes everything of importance
# produced by the XmlResolution class.
 
class ResolverCollection

  # Timeout in seconds for the read_lock and write_lock methods.

  LOCK_TIMEOUT = 10

  # The collection id, a string, usually a simple IEID.  Cannot have funny characters.  

  attr_reader :collection_identifier

  # The proxy to use, if any.  A string comprised of host name and port such as 'sake.fcla.edu:8000'.
  # Port will default to 3128, commonly used for the squid caching server, which the FDA uses.

  attr_reader :proxy

  # A string naming the root directory where persistent object state (that it, files) are kept.

  attr_reader :root_directory

  # A string naming the directory where collections are stored: one subdirectory per collection identifier.

  attr_reader :collection_path
  
  # A string naming the directory where schemas are stored.
  
  attr_reader :schemas_path


  # Create a new collection identified by IDENTIFIER.  Information produced by other methods on
  # this class are stored in the directory ROOT_DIRECTORY.  A caching proxy, if supplied, is
  # identified by the string PROXY, usually as "hostname:port".   The object can be used to
  # run the XmlResolution procedure against XML documents.  The information so produced  will
  # be associated with this collection.

  def initialize(root_directory, identifier, proxy = nil)
    
    @collection_identifier = identifier

    raise "Invalid identifier #{identifier}" if identifier =~ /\// or identifier != URI.escape(identifier)

    @proxy           = proxy
    @root_directory  = root_directory

    raise "No such root directory #{@root_directory}."                   unless File.directory? @root_directory
    raise "No permission to write to root directory #{@root_directory}." unless File.writable?  @root_directory
    
    @schemas_path    = File.join(root_directory, 'schemas')
    @collection_path = File.join(root_directory, 'collections', collection_identifier)
    
    FileUtils.mkdir_p @schemas_path
    FileUtils.mkdir_p @collection_path

  # The following leaks too much information, maybe

  rescue => e
    raise "Can't create resolution collection object for #{collection_identifier} in #{root_directory}: #{e.message}"
  end


  # report the collection names - a list of IEIDs, normally

  def self.collections root_directory
    list = []
    root =  File.join(root_directory, 'collections', '*')
    Dir[root].each do |filepath|
      next unless File.directory? filepath
      list.push  filepath.gsub(/^#{root}/, '')
    end
    list.sort
  end

  # does a collection exist?

  def self.collection_exists? root_directory, collection
    collections(root_directory).include? collection
  end
  


  private

  # Given the list of records produced by
  # XmlResolution#schema_information, find those successfully
  # resolved schemas and store them into files named after their MD5
  # digests. Also, for each schema, yield that digest information
  # along with the associated location and its namespace.

  def save_and_note_schema_files(info_list)
    info_list.each do |rec| # :body :digest :error_message :last_modified :location :namespace :processing_time :status         

      next if rec[:status] != :success

      schema_abs_path = File.join(schemas_path, rec[:digest]) 

      yield rec[:digest], rec[:location], rec[:namespace], rec[:last_modified], File.join('schemas', rec[:digest])

      next if File.exists? schema_abs_path  and  File.mtime(schema_abs_path) == rec[:last_modified]
      open schema_abs_path, 'w' do |fd|
        fd.write rec[:body]
      end      
      File.utime(File.atime(schema_abs_path), rec[:last_modified], schema_abs_path)
    end
  end

  # Given the list of information produced by
  # XmlResolution#schema_information, find those schemas that
  # failed: for each of them yield their location, namespace, and the
  # error message that occured when processing them.

  def report_broken_schemas(info_list)
    info_list.each do |rec|
      next if rec[:status] == :success
      yield rec[:location], rec[:namespace], rec[:error_message]
    end
  end

  # Access the file FILEPATH exclusively. Times out after LOCK_TIMEOUT seconds.  Truncates
  # the file, and yields a file descriptor ready to write to.

  def write_lock(filepath)
    open(filepath, 'w') do |fd|
      Timeout.timeout(LOCK_TIMEOUT) { fd.flock(File::LOCK_EX) }
      yield fd
    end
  rescue Timeout::Error => e
    raise "Timed out waiting #{LOCK_TIMEOUT} seconds for write lock to #{filepath}: #{e.message}"
  end

  # Access the file FILEPATH in a shared manner: many read_locks can be active, but only
  # one write_lock.  Timeouts after LOCK_TIMEOUT seconds, and yields a file desciptor ready
  # to read from.

  def read_lock(filepath)
    open(filepath, 'r') do |fd|
      Timeout.timeout(LOCK_TIMEOUT) { fd.flock(File::LOCK_SH) }
      yield fd
    end
  rescue Timeout::Error => e
    raise "Timed out waiting #{LOCK_TIMEOUT} seconds for read lock to #{filepath}: #{e.message}"
  end
  
  # Given a list of strings, first URI escape them, then join them with a space and
  # return the constructed string.

  def escape(*list)
    list.map{ |elt| URI.escape(elt) }.join(' ')
  end

  # Perform the inverse of the escape method.

  def unescape(string)
    data = string.split(/\s+/)
    data.map{ |elt| URI.unescape(elt) }
  end

  # Loop over all of our resolution_data files, providing each path.  The paths
  # are suitable for using as arguments to get_resolution_data.

  def list_resolution_data_files 
    Dir[ File.join(collection_path, '*') ].each do |filepath|
      next if File.directory? filepath
      next unless filepath =~ /[a-z0-9]{32}/        
      yield filepath
    end
  end

  # Given the string FILEPATH, open the named file and get out the resolution_data from it.

  def get_resolution_data(filepath)

    # We are given the string FILEPATH, the location of a file such as
    # <root>/collections/E20071201_AAABCD/789ff2cf70da382ddf59339293e61456
    # It has all the resolution_data we preserve for a particular XML
    # document that was associated with the collection E20071201_AAABCD.  Here's 
    # an example:
    #
    # FILENAME test.xml
    # SCHEMA c703435da3490c8bbd58b69fad125017 http://www.loc.gov/standards/mets/mets.xsd http://www.loc.gov/METS/ schemas/c703435da3490c8bbd58b69fad125017 2009-05-05T14:40:48-04:00
    # SCHEMA 54fbb3ef95c5f2f0d89a9c755e9b616e http://www.fcla.edu/dls/md/daitss/daitss.xsd http://www.fcla.edu/dls/md/daitss/ schemas/54fbb3ef95c5f2f0d89a9c755e9b616e 2007-07-27T15:12:52-04:00
    # SCHEMA 446839f319de8d5b40871c9da8f99c37 http://www.fcla.edu/dls/md/palmm.xsd http://www.fcla.edu/dls/md/palmm/ schemas/446839f319de8d5b40871c9da8f99c37 2006-06-16T14:39:11-04:00
    # SCHEMA a166f873a7607ebcec83c01354f300af http://www.fcla.edu/dls/md/techmd.xsd http://www.fcla.edu/dls/md/techmd/ schemas/a166f873a7607ebcec83c01354f300af 2004-09-29T17:30:36-04:00
    # SCHEMA 86a5c9c8c17b91c97be61847218fe823 http://www.fcla.edu/dls/md/rightsmd.xsd http://www.fcla.edu/dls/md/rightsmd/ schemas/86a5c9c8c17b91c97be61847218fe823 2004-09-29T17:30:36-04:00
    # SCHEMA afd985136a7e721cfafa062287a27f45 http://dublincore.org/schemas/xmls/simpledc20021212.xsd http://purl.org/dc/elements/1.1/ schemas/afd985136a7e721cfafa062287a27f45 2009-11-03T13:34:01-05:00
    # UNRESOLVED_NAMESPACES http://www.w3.org/1999/xlink http://www.w3.org/2001/XMLSchema-instance
    #
    # the SCHEMA lines include the checksum of the downloaded schema file needed to resolve the document; it
    # is followed by the retrieved location, namespace, the relative location of the schema document, and the
    # timestamp of the schema document.
    
    info = { 
      'error'               => nil,  
      'name'                => nil, 
      'unresolved'          => [], 
      'bad-schemas'         => [], 
      'good-schemas'        => [], 
      'document_identifier' => File.basename(filepath), # recall, this is the md5 sum of the contents of the xml document
    }

    read_lock(filepath) do |fd|
      fd.readlines.each do |line|
        data = unescape(line.chomp)
        case data.shift
        when 'FILENAME'       
          info['name']  =  data.shift
        when 'RESOLUTION_FAILURE'    
          info['error'] =  data[0]
        when 'SCHEMA'                
          info['good-schemas'].push({ 'md5' => data[0], 'location' => data[1], 'namespace' => data[2], 'pathname' => data[3], 'mtime' => data[4] })
        when 'UNRESOLVED_NAMESPACES' 
          info['unresolved'] = data
        when 'BROKEN_SCHEMA'         
          info['bad-schemas'].push({ 'location' => data[0], 'namespace' => data[1], 'reason' => data[2] })
        end
      end        
    end # of read_lock

    info
  end


  # given a FILEPATH to a meta document, convert to an xml fragment

  def resolution_data_to_xml(xmldoc, resolution_data)

    xmldoc.resolution(:name => resolution_data['name'], :id => resolution_data['document_identifier']) {

      if resolution_data['error']
        xmldoc.status(:outcome => 'failure') { xmldoc.error_message(resolution_data['error']) }
      else
        xmldoc.status(:outcome => 'success')     
      end

      if not resolution_data['unresolved'].empty?
        resolution_data['unresolved'].each do |elt|
          xmldoc.schema(:status => 'unresolved', :namespace => elt)
        end
      end

      if not resolution_data['good-schemas'].empty?
        resolution_data['good-schemas'].each do |elt| 
          xmldoc.schema(:status => 'success', :namespace => elt['namespace'], :location => elt['location'], :url => elt['pathname'], :md5 => elt['md5'])
        end
      end

      if not resolution_data['bad-schemas'].empty?
        resolution_data['bad-schemas'].each do |elt| 
          xmldoc.schema(:status => 'failure', :namespace => elt['namespace'], :location => elt['location'], :message => elt['reason'])
        end
      end
    }
  end

  # utf8 ensures we won't smash the current value of KCODE

  def utf8
    the_value_formerly_known_as_kcode = $KCODE
    $KCODE = 'UTF8'
    yield
  ensure 
    $KCODE = the_value_formerly_known_as_kcode
  end

  public

  # For the given DOCUMENT_TEXT, a string containing an XML document,
  # and optionally the string FILENAME, run the xml resolution
  # procedure over it and store the information it produces into this
  # collection.  Returns an xml snippet describing the outcome
  # of processing the text.  The intent for FILENAME is that it be a
  # filename from a form/mulipart submission, or similar.  If we've previously
  # stored this particular document, over-write the last set of data.

  def save_resolution_data(document_text, filename)

    # We use the md5 checksum of the document text to identify the
    # file.  In fact, we'll store all the data about this file in a
    # simple text file using the checksum as the filename. We have
    # a half dozen or so keywords, and specific data following.  We'll
    # URI encode in that file anything that a user could game us with...

    document_digest   = Digest::MD5.hexdigest(document_text)
    resolution_data_pathname = File.join(collection_path, document_digest)

    write_lock(resolution_data_pathname) do |fd|
      fd.puts escape('FILENAME',  filename)
      begin
        rez = XmlResolver.new(document_text, proxy)
      rescue => e
        fd.puts escape('RESOLUTION_FAILURE', e.message)
      else
        save_and_note_schema_files(rez.schema_information)  do |digest, location, namespace, mtime, schema_pathname|
          fd.puts escape('SCHEMA', digest, location, namespace, schema_pathname, mtime.iso8601)
        end
        fd.puts escape('UNRESOLVED_NAMESPACES', *rez.unresolved_namespaces)      
        report_broken_schemas(rez.schema_information) do |location, namespace, reason|
          fd.puts escape('BROKEN_SCHEMA', location, namespace, reason)
        end
      end
    end   # of write_lock

### looks like I really want the premis document, for just this xml

    utf8 do
      xml = Builder::XmlMarkup.new(:indent => 2)    
      xml.instruct!(:xml, :encoding => 'UTF-8')
      resolution_data_to_xml(xml, get_resolution_data(resolution_data_pathname))
      xml.target!
    end
  end

  # Report all of the information we've made so far for this collection as
  # string containing an XML document.

  def xml_report
    utf8 do
      xml = Builder::XmlMarkup.new(:indent => 2)    
      xml.instruct!(:xml, :encoding => 'UTF-8')
      xml.resolutions(:collection => collection_identifier) {
	list_resolution_data_files do |filepath|
	  resolution_data_to_xml(xml, get_resolution_data(filepath))
	end
      }
      xml.target!
    end
  end

  # Tar up the entire collection and write it out to FD, a File object.

  def tar(fd)
    tarfile = TarWriter.new(fd, { :uid => 80, :gid => 80, :username => 'daitss', :groupname => 'daitss' })

    Tempfile.open('manifest') do |tmp|
      tmp.write(xml_report)
      tmp.close
      FileUtils.chmod(0644, tmp.path)
      tarfile.write(tmp.path, File.join(collection_identifier, 'manifest.xml'))
    end

    schema_locations = {}

    list_resolution_data_files do |filepath|
      data = get_resolution_data(filepath)
      data['good-schemas'].each do |rec|
        schema_locations[rec['location']] =  rec['pathname']
      end
    end

    schema_locations.keys.sort.each do |key|
      location = File.join(collection_identifier, key)
      filepath = File.join(root_directory, schema_locations[key])

      tarfile.write(filepath, location)
    end

    tarfile.close
  end

end # of class


