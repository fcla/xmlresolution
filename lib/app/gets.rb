# This top page provides help and documentation:

get '/' do
  erb :site, :locals => { :base_url => service_name, :revision => XmlResolution.version.rev }
end

# List the collections we've created

get '/ieids' do
  redirect '/ieids/', 301
end

get '/ieids/' do
  erb :ieids , :locals => { :collections =>  ResolverCollection.collections(options.data_path).sort }
end

# Return a tarfile of all of the schemas we've collected for the xml documents submitted
# to this collection resource:

get '/ieids/:collection_id' do |collection_id|
   redirect "/ieids/#{collection_id}/", 301
end

get '/ieids/:collection_id/' do |collection_id|
  raise Http404, "No such IEID #{collection_id}" unless ResolverCollection.collections(options.data_path).include? collection_id 

  attachment   "#{collection_id}.tar"
  content_type "application/x-tar"
  ResolverCollection.new(options.data_path, collection_id).tar do |io|
    io.read
  end
end

# Just the manifest xml file from a collection.

get '/ieids/:collection_id/manifest.xml' do |collection_id|
  raise Http404, "No such IEID #{collection_id}" unless ResolverCollection.collections(options.data_path).include? collection_id 

  content_type 'application/xml'
  ResolverCollection.new(options.data_path, collection_id).manifest
end

# Documentation, built by rake and placed in the public folder.

get '/docs/?' do
   redirect '/internals/index.html', 301
end

# Test form for submitting an XML document via a file upload form:

get '/test' do
  redirect '/test/', 301
end

get '/test/' do
  erb :test, :locals => { :collections => ResolverCollection.collections(options.data_path).sort }
end

get '/test-form/:collection_id/' do |collection_id|
  erb :'test-form', :locals => { :collection_id => collection_id }
end
