require 'tempfile'
require 'uri'
require 'fileutils'
require 'xmlresolver/resolvercollection.rb'
require 'xmlresolver/tarwriter.rb'
require 'xmlresolver/xmlresolver.rb'
require 'yaml'

require 'debugger'

# TODO: remove old collections on the fly (say, after a week...) and support HEAD, DELETE, 400's, etags, and schema files

helpers do

  def app_root
    File.expand_path(File.dirname(__FILE__))
  end

  # so far, anything that requires a configuration variable knows how 
  # to default from a nil value; TODO log a warning

  def configuration name
    filename = File.join app_root, 'config.yaml'
    YAML::load_file(filename)[name]
  rescue => e
    STDERR.puts "Warning: expected a configuration file #{filename}. Returning nil for the #{name} configuration variable."
    return nil
  end

  def hostname
    Socket::gethostname.downcase
  end
  
  def data_root
    File.join app_root, 'data'
  end

  def proxy
    configuration 'proxy'
  end

  def collection_name_ok? collection_id
    # collection_id =~ /^E2[0-9]{7}_[a-zA-Z0-9_]{6}$/
    not (collection_id =~ /\// or collection_id != URI.escape(collection_id))
  end

  def collection_exists? collection_id
    ResolverCollection.collection_exists? data_root, collection_id
  end

  def collections
    ResolverCollection.collections data_root
  end
  
  def create_collection collection_id
    ResolverCollection.new(data_root, collection_id) 
  end

  def tar_file_as_string collection_id
    fd = Tempfile.new 'xmlrez-tar'
    ResolverCollection.new(data_root, collection_id, proxy).tar(fd)
    fd.open.read
  rescue => e
    halt [ 500, e.message + "\n" ]  # TODO: close potential security problem - information leakage
  ensure
    fd.close
  end

  def add_xml_file_data collection_id, tempfile, filename=nil 
    tempfile.open                                                  # reopens in read mode
    rc = ResolverCollection.new(data_root, collection_id, proxy)   
    rc.save_resolution_data(tempfile.read, filename)               # returns an xml document describing the outcome
  end

end # of helpers


# Clients that forgot trailing slashes:

get '/ieids' do
  redirect '/ieids/', 301
end

get '/ieids/:collection_id' do |collection_id|
  redirect "/ieids/#{collection_id}/", 301
end

get '/rdoc' do 
  redirect '/rdoc/index.html', 301
end

get '/rdoc/' do 
  redirect '/rdoc/index.html', 301
end

get '/test' do
  redirect '/test/', 301
end

# The top level page gives an introduction to using this service.

get '/' do
  port = @env['SERVER_PORT'].to_s
  base_url = 'http://' + @env['SERVER_NAME'] + (port == '80' ? '' : ":#{port}")
  erb :site, :locals => { :base_url => base_url }
end

# List all of the collections we've got

get '/ieids/' do
  erb :ieids
end

# Get the collection of xml files we've associated with a collection id as a tar file

get '/ieids/:collection_id/' do |collection_id|
  halt [ 404, "No such collection #{collection_id}\n" ] unless collection_exists? collection_id
  content_type "application/x-tar"
  attachment   "#{collection_id}.tar"
  tar_file_as_string collection_id
end

# Create a new collection:

put '/ieids/:collection_id' do |collection_id|
  halt [ 403, "Collection #{collection_id} already exists\n" ]  if collection_exists? collection_id
  halt [ 400, "Collection #{collection_id} is badly named\n" ]  unless collection_name_ok? collection_id
  create_collection collection_id
  status 201
  "collection #{collection_id} created\n"
end


# POST an xmlfile to a resource collection.
#
# We expect Content-Type of enctype=multipart/form-data, which is used in your basic file upload form.
# It expects behavior produced as the form input having type="file" name="xmlfile".  Additionally, if
# the content disposition supplies a filename, we'll use that.

post '/ieids/:collection_id/' do |collection_id|

  halt [ 400, "Missing required parameter 'xmlfile'\n" ] unless params['xmlfile']

  tempfile = params['xmlfile'][:tempfile]
  filename = params['xmlfile'][:filename] or 'unnamed.xml'    # TODO:  need to raise an exception here: filename is now required

  content_type "application/xml"
  status 200
  add_xml_file_data(collection_id, tempfile, filename)   # TODO:  percolate errors up to here
end

get '/test/' do
   erb :test
end

get '/test-form/:collection_id/' do |collection_id|
  erb :'test-form', :locals => { :collection_id => collection_id }
end

get '/dump' do
  raise
end

post '/dump' do
  raise
end

