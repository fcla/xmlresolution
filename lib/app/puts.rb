# PUT a new collection resource id.

put '/ieids/:collection_id' do |collection_id|
  content_type 'text/plain'

  if ResolverCollection.collections(settings.data_path).include? collection_id
    status 200
    "Collection #{collection_id} exists.\n"
  else
    ResolverCollection.new settings.data_path, collection_id
    status 201
#      $iostats.collections += 1
    "Collection #{collection_id} created.\n"
  end

end
