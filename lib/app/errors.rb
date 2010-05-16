# -*- coding: utf-8 -*-

error do
  e = @env['sinatra.error']

  # Passenger phusion complains to STDERR about the dropped body data unless we rewind.

  request.body.rewind if request.body.respond_to?('rewind')  

  # The XmlResolution::HttpError exception classes carry along their own status texts and HTTP status codes.

  if e.is_a? XmlResolution::HttpError
    Logger.err e.client_message, @env
    [ halt e.status_code, { 'Content-Type' => 'text/plain' }, e.client_message ]    
  else
    Logger.err "Internal Service Error - #{e.message}", @env
    e.backtrace.each { |line| Logger.err line, @env }
    [ halt 500, { 'Content-Type' => 'text/plain' }, "Internal Service Error.\n" ]
  end
end

# Urg.  The not_found RACK/sinatra method grabs *my* ( [ halt(404), ... ], a Bad
# We repeat the code above for this special case.

not_found  do
  message = if @env['sinatra.error'].is_a? XmlResolution::Http404 
              e.client_message
            else
              "404 Not Found - #{request.url} doesn't exist.\n"
            end
  Logger.warn message, @env
  content_type 'text/plain'
  message
end
