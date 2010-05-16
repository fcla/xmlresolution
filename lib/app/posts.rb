# POST an xmlfile to a resolution collection.
#
# We expect Content-Type of enctype=multipart/form-data, which is used
# in your basic file upload form.  It expects behavior produced as the
# form input having type="file" name="xmlfile".  Additionally, we
# require that the content disposition must supply a filename.


post '/ieids/:collection_id/' do |collection_id|

  begin
    raise Http400, "Missing form data name='xmlfile'"    unless params['xmlfile']
    raise Http400, "Missing form data filename='...'"    unless filename = params['xmlfile'][:filename]
    raise Http500, "Data unavailable (missing tempfile)" unless tempfile = params['xmlfile'][:tempfile]

    if not ResolverCollection.collections(settings.data_path).include? collection_id
      raise Http400, "Collection #{collection_id} doesn't exist: use PUT #{service_name}/ieids/#{collection_id} first to create it"
    end

    res = XmlResolver.new(tempfile.open.read, "file://#{@env['REMOTE_ADDR']}/#{filename.gsub(%r(^/+), '')}", 
                          settings.data_path, settings.proxy)
    res.process
    res.save collection_id

    status 201
    content_type 'application/xml'
    res.premis_report
  ensure
    tempfile.unlink if tempfile.respond_to? 'unlink'
  end

end
