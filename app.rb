require 'tempfile'
require 'uri'
require 'fileutils'
require 'xmlresolution.rb'

# TODO: logger, and use as before method
# TODO: remove old collections on the fly (say, after a week...)
# TODO: support HEAD, DELETE, etags and last-modified

configure do
  $KCODE = 'UTF8'
  XmlResolution::ResolverCollection.data_path = File.expand_path(File.join(File.dirname(__FILE__), 'data'))
  set :proxy, 'sake.fcla.edu'
end

helpers do
  def service_name
    'http://' + @env['SERVER_NAME'] + (@env['SERVER_PORT'] == '80' ? '' : ":#{@env['SERVER_PORT']}")
  end

  def tar_up collection_id
    tmp = Tempfile.new 'xmlrez-tar-'
    XmlResolution::ResolverCollection.new(collection_id).tar(tmp)
    tmp.open.read
  ensure 
    tmp.close
  end

  def bt e
    e.backtrace.join("\n") + "\n"
  end
end # of helpers

# Help out clients that forgot trailing slashes:

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
  erb :site, :locals => { :base_url => service_name }
end

# List all of the collections we've got

get '/ieids/' do
  erb :ieids, :locals => { :collections => XmlResolution::ResolverCollection.collections.sort }
end

# Return a tarfile of all of the schemas we've collected for the xml documents submitted
# to this service.

get '/ieids/:collection_id/' do |collection_id|

  content_type "text/plain"
  [ halt 404, "No such collection #{collection_id}\n" ] unless XmlResolution::ResolverCollection.collection_exists? collection_id 

  begin
    data = tar_up collection_id
  rescue XmlResolution::Http400Error => e
    halt [ 400, e.message + "\n" ]
  rescue => e
    halt [ 500, "Error creating tarfile for collection #{collection_id}: #{e.message}.\n" + bt(e) ]
  else
    content_type "application/x-tar"
    attachment   "#{collection_id}.tar"
    data
  end
end

# Create a new collection.

put '/ieids/:collection_id' do |collection_id|
  begin
    content_type 'text/plain'
    if XmlResolution::ResolverCollection.collection_exists? collection_id
      status 200
      "Collection #{collection_id} existed.\n"
    else
      XmlResolution::ResolverCollection.new collection_id
      status 201
      "Collection #{collection_id} created.\n"
    end
  rescue XmlResolution::Http400Error => e
    halt [ 400, e.message + "\n" ]
  rescue => e
    halt [ 500, e.message + "\n" + bt(e) ]
  end
end


# POST an xmlfile to a resource collection.
#
# We expect Content-Type of enctype=multipart/form-data, which is used in your basic file upload form.
# It expects behavior produced as the form input having type="file" name="xmlfile".  Additionally, we
# require that the content disposition must supply an original filename.

# TODO: I notice that a brand new collection might be created on the fly here: bug? Or feature?

post '/ieids/:collection_id/' do |collection_id|
  begin
    content_type 'text/plain'

    halt [ 400, "Missing form data name='xmlfile'\n" ]    unless params['xmlfile']
    halt [ 400, "Missing form data filename='...'\n" ]    unless filename = params['xmlfile'][:filename]
    halt [ 500, "Data unavailable (missing tempfile)\n" ] unless tempfile = params['xmlfile'][:tempfile]

    xrez = XmlResolution::XmlResolver.new(tempfile.open.read, options.proxy)
    xrez.filename = filename

    XmlResolution::ResolverCollection.new(collection_id).add xrez

  rescue XmlResolution::Http400Error => e
    halt [ 400, e.message + "\n" ]
  rescue => e
    halt [ 500, "Can't process file #{filename} for collection #{collection_id}: #{e.message}.\n"  + bt(e) ]
  else
    status 201
    content_type 'application/xml'
    XmlResolution.xml_resolver_report xrez, service_name 
  end
end

get '/test/' do
  erb :test, :locals => { :collections => XmlResolution::ResolverCollection.collections.sort }
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
