# This top page provides help and documentation:

get '/' do
  erb :site, :locals => { :base_url => service_name, :revision => XmlResolution.version.rev }
end

# List the collections we've created

get '/ieids' do
  redirect '/ieids/', 301
end

get '/ieids/' do
  erb :ieids , :locals => { :collections =>  ResolverCollection.collections(settings.data_path).sort }
end

# Return a tarfile of all of the schemas we've collected for the xml documents submitted
# to this collection resource:

get '/ieids/:collection_id' do |collection_id|
   redirect "/ieids/#{collection_id}/", 301
end

get '/ieids/:collection_id/' do |collection_id|
  raise Http404, "No such IEID #{collection_id}" unless ResolverCollection.collections(settings.data_path).include? collection_id 

  attachment   "#{collection_id}.tar"
  content_type "application/x-tar"
  ResolverCollection.new(settings.data_path, collection_id).tar do |io|
    io.read
  end
end

# Just the manifest xml file from a collection.

get '/ieids/:collection_id/manifest.xml' do |collection_id|
  raise Http404, "No such IEID #{collection_id}" unless ResolverCollection.collections(settings.data_path).include? collection_id 

  content_type 'application/xml'
  ResolverCollection.new(settings.data_path, collection_id).manifest
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
  erb :test, :locals => { :collections => ResolverCollection.collections(settings.data_path).sort }
end

get '/test-form/:collection_id/' do |collection_id|
  erb :'test-form', :locals => { :collection_id => collection_id }
end

get '/status' do
  [ 200, {'Content-Type'  => 'application/xml'}, "<status/>\n" ]
end
=begin 
get '/stats' do
stats = '<h1><b>DAITSS XMLResolution Statistics</b></h1>'	
stats = stats << "<br><h3> running since: #{$iostats.startup_time}<h3>"
stats = stats << '<table border="1" style="background-color:magenta"><th><h3><b>Current</b></h3></th>'
stats =  stats << "<tr><td><b>Collections</b><td>#{$iostats.collections}</td></tr>"
stats =  stats << "<tr><td><b>Schemas/DTDs/PIs<td>#{$schema_references.size}</td></tr>"
stats =  stats << "<tr><td><b>URL Reads</b></td><td>#{$iostats.url_reads}</td><tr>"
stats =  stats << "<tr><td><b>URL Bytes Read</b></td><td>#{$iostats.url_bytes_read}</td><tr>"
stats =  stats << "<tr><td><b>Storage Writes</b></td><td>#{$iostats.writes}</td><tr>"
stats =  stats << "<tr><td><b>Bytes Written</b></td><td>#{$iostats.bytes_written}</td><tr>"
stats =  stats << "<tr><td><b>Successes</b></td><td>#{$iostats.successes}</td><tr>"
stats =  stats << "<tr><td><b>Redirects</b></td><td>#{$iostats.redirect_cases}</td><tr>"
stats =  stats << "<tr><td><b>Unresolveds</b></td><td>#{$iostats.fails}</td><tr>"
stats =  stats << '<tr><td><b>Ref Count</b></td><td><b>Date</b></td><td><b>MD5</b></td><td><b>Schema/DTD/PI</b></td></tr>'
$schema_references.keys.each do |k|
  val = $schema_references[k]
  stats = stats << '<tr>' << "<td>#{val}</td><td>#{$MD5toRecord[k].last_modified.iso8601}</td><td>#{k}</td><td>#{$MD5toRecord[k].location}</td></tr>"
end
stats = stats << '</th></table>'
end
end
=end
