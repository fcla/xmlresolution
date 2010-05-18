# POST an XML file to a resolution collection.
#
# We expect Content-Type of enctype=multipart/form-data, which is used
# in your basic file upload form.  It expects the same behavior as
# produced by the form input having type="file" name="xmlfile".
# Additionally, we require that the content disposition must supply a
# filename.


post '/ieids/:collection_id/' do |collection_id|

  begin
    raise Http400, "Missing form data name='xmlfile'"    unless params['xmlfile']
    raise Http400, "Missing form data filename='...'"    unless filename = params['xmlfile'][:filename]
    raise Http500, "Data unavailable (missing tempfile)" unless tempfile = params['xmlfile'][:tempfile]

    if not ResolverCollection.collections(settings.data_path).include? collection_id
      raise Http400, "Collection #{collection_id} doesn't exist: use PUT #{service_name}/ieids/#{collection_id} first to create it"
    end

    client = ResolverUtils.remote_name env['REMOTE_ADDR']

    file_url = "file://#{client}/#{filename.gsub(%r(^/+), '')}"

    Logger.info "Handling uploaded document #{file_url}.", @env

    res = XmlResolver.new(tempfile.open.read, file_url, settings.data_path, settings.proxy)

    res.process
    res.save collection_id

    res.schema_dictionary.map do |record|  
      if record.retrieval_status == :failure
        Logger.err  "Failed retrieving #{record.location} for document #{file_url}, namespace #{record.namespace}, error #{record.error_message}.", @env
      end
      if record.retrieval_status == :success 
        Logger.info "Retrieved #{record.location} for document #{file_url}, namespace #{record.namespace}.", @env
      end
      if record.retrieval_status == :redirect
        Logger.info "Schema #{record.location} for document #{file_url}, was redirected to #{record.redirected_location}.", @env
      end
    end

    res.unresolved_namespaces.each { |ns|  Logger.warn "Unresolved namespace #{ns} for document #{file_url}.", @env }

    status 201
    content_type 'application/xml'
    res.premis_report
  ensure
    tempfile.unlink if tempfile.respond_to? 'unlink'
  end
end
