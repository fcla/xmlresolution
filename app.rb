require 'tempfile'
require 'xmlresolution.rb'

# TODO: support HEAD, DELETE (for collection), etags and last-modified, accept headers

include XmlResolution

# ENV variables RESOLVER_PROXY and LOG_FACILITY are set up in the
# apache configuration file for this virtual host.

configure do
  $KCODE = 'UTF8'

  ResolverCollection.data_path = File.join(File.dirname(__FILE__), 'data')

  set :proxy, ENV['RESOLVER_PROXY']

  Logger.filename = File.join(File.dirname(__FILE__), 'logs', 'xmlresolution.log')
  Logger.facility = ENV['LOG_FACILITY'] unless ENV['LOG_FACILITY'].nil?
  use Rack::CommonLogger, Logger.new
end

helpers do

  def tar_up xrez
    tmp = Tempfile.new 'xmlrez-tar-'
    xrez.tar(tmp)
    tmp.open.read
  ensure 
    tmp.close
  end

  def service_name
    'http://' + @env['SERVER_NAME'] + (@env['SERVER_PORT'] == '80' ? '' : ":#{@env['SERVER_PORT']}")
  end

end # of helpers

# before do
#   XmlResolution::Logger.info  env, 'Starting request....'  
# end


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
  erb :site, :locals => { :base_url => service_name, :revision => REVISION }
end

# List all of the collections we've got

get '/ieids/' do
  erb :ieids, :locals => { :collections => ResolverCollection.collections.sort }
end

# Return a tarfile of all of the schemas we've collected for the xml documents submitted
# to this service.

get '/ieids/:collection_id/' do |collection_id|

  content_type "text/plain"
  [ halt 404, "No such collection #{collection_id}\n" ] unless ResolverCollection.collection_exists? collection_id 

  begin
    xrez = ResolverCollection.new(collection_id)
    last_modified xrez.httpdate   # bails immediately w/o tar creation overhead, if possible
    data = tar_up xrez
  rescue Http400Error => e
    halt [ 400, e.message + "\n" ]
  rescue => e
    Logger.err e.message, @env
    e.backtrace.each { |line| Logger.err line, @env }
    halt [ 500, "Error creating tarfile for collection #{collection_id}\n" ]
  else
    content_type "application/x-tar"
    attachment   "#{collection_id}.tar"
    data
  end
end

# PUT a new collection resource.

put '/ieids/:collection_id' do |collection_id|
  begin
    content_type 'text/plain'
    if ResolverCollection.collection_exists? collection_id
      status 200
      "Collection #{collection_id} exists.\n"
    else
      ResolverCollection.new collection_id
      status 201
      "Collection #{collection_id} created.\n"
    end
  rescue Http400Error => e
    halt [ 400, e.message + "\n" ]
  rescue => e
    Logger.err e.message, @env
    e.backtrace.each { |line| Logger.err line, @env }
    halt [ 500, "We're sorry, there was a problem creating the collection #{collection_id}. Please contact customer support.\n" ]
  end
end

# POST an xmlfile to a resource collection.
#
# We expect Content-Type of enctype=multipart/form-data, which is used
# in your basic file upload form.  It expects behavior produced as the
# form input having type="file" name="xmlfile".  Additionally, we
# require that the content disposition must supply an original
# filename.
#
# TODO: I notice that a brand new collection might be created on the
# fly here: bug? Or feature?

post '/ieids/:collection_id/' do |collection_id|
  begin
    content_type 'text/plain'

    halt [ 400, "Missing form data name='xmlfile'\n" ]    unless params['xmlfile']
    halt [ 400, "Missing form data filename='...'\n" ]    unless filename = params['xmlfile'][:filename]
    halt [ 500, "Data unavailable (missing tempfile)\n" ] unless tempfile = params['xmlfile'][:tempfile]

    xrez = XmlResolver.new(tempfile.open.read, options.proxy)
    xrez.filename = filename

    ResolverCollection.new(collection_id).add xrez

  rescue Http400Error => e
    halt [ 400, e.message + "\n" ]
  rescue => e
    Logger.err e.message, @env
    e.backtrace.each { |line| Logger.err line, @env }
    
    halt [ 500, "Can't process file #{filename} for collection #{collection_id}.\n"]
  else
    status 201
    content_type 'application/xml'
    XmlResolution.xml_resolver_report xrez
  end
end

get '/test/' do
  erb :test, :locals => { :collections => ResolverCollection.collections.sort }
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
