require 'tempfile'
require 'uri'
require 'fileutils'
require 'xmlresolver/resolvercollection.rb'
require 'xmlresolver/tarwriter.rb'
require 'xmlresolver/xmlresolver.rb'
require 'yaml'

require 'debugger'  # TODO: this is a crock... do better

# TODO: logger
# TODO: configuration section?
# TODO: remove old collections on the fly (say, after a week...) and
# support HEAD, DELETE, 400's, etags, and schema files


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
    # collection_id =~ /^E2[0-9]{7}_[a-zA-Z0-9_]{6}$/                           # need to add this back
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

  def get_tarfile collection_id
    fd = Tempfile.new 'xmlrez-tar'
    ResolverCollection.new(data_root, collection_id, proxy).tar(fd)
    fd.open.read
  ensure
    fd.close true
  end

  def add_xml collection_id, xml_text, xml_filename
    rc = ResolverCollection.new(data_root, collection_id, proxy)   
    rc.save_resolution_data(xml_text, xml_filename)                # returns an xml document describing the outcome
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

  base_url = 'http://' + @env['SERVER_NAME'] + (@env['SERVER_PORT'] == '80' ? '' : ":#{@env['SERVER_PORT']}")
  erb :site, :locals => { :base_url => base_url }
end

# List all of the collections we've got

get '/ieids/' do
  erb :ieids
end


# Get the collection of xml files we've associated with a collection id as a tar file

get '/ieids/:collection_id/' do |collection_id|
  begin
    halt [ 404, "No such collection /ieids/#{collection_id}\n" ] unless collection_exists? collection_id
    tar_data = get_tarfile collection_id
    content_type "application/x-tar"
    attachment   "#{collection_id}.tar"
    tar_data
  rescue => e
    content_type "text/plain"
    halt [ 500, "Error creating tarfile.\n" ]  # TODO: be nice to get a backtrace in a log somewhere....
  end
end

# Create a new collection:

put '/ieids/:collection_id' do |collection_id|
  halt [ 403, "Collection #{collection_id} already exists\n" ]  if collection_exists? collection_id
  halt [ 400, "Collection #{collection_id} is badly named\n" ]  unless collection_name_ok? collection_id

  create_collection collection_id  ### TODO: catch error
  status 201
  "collection #{collection_id} created\n"
end


# POST an xmlfile to a resource collection.
#
# We expect Content-Type of enctype=multipart/form-data, which is used in your basic file upload form.
# It expects behavior produced as the form input having type="file" name="xmlfile".  Additionally, we
# content disposition must supply a filename.

post '/ieids/:collection_id/' do |collection_id|
  begin
    halt [ 400, "Missing form data name='xmlfile'\n" ]    unless params['xmlfile']
    halt [ 400, "Missing form data filename='...'\n" ]    unless filename = params['xmlfile'][:filename]
    halt [ 500, "Data unavailable (missing tempfile)\n" ] unless tempfile = params['xmlfile'][:tempfile]
    
    status 200
    content_type 'application/xml'
    add_xml(collection_id, tempfile.open.read, filename)   # TODO:  sic - raise and catch specific errors (e.g. non-xmlfiles)

  rescue => e
    content_type 'text/plain'
    halt [ 500, "Can't get filedata for #{filename}.\n" ]
  end
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

