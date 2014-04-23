# -*- coding: utf-8 -*-

error do
  e = @env['sinatra.error']

  # Passenger phusion complains to STDERR about the dropped body data unless we rewind.

  request.body.rewind if request.body.respond_to?('rewind')  

  # The XmlResolution::HttpError exception classes carry along their own status texts and HTTP status codes.
  if e.is_a? XmlResolution::HttpError
	  Datyl::Logger.err "e.is_a=true status_code=#{e.status_code} client_message=#{e.client_message}"
    halt e.status_code, { 'Content-Type' => 'text/plain' }, e.client_message      # ruby 1.9.3
  else
	  Datyl::Logger.err "e..is_a?=false"
    Datyl::Logger.err "Internal Service Error - #{e.message}", @env
    e.backtrace.each { |line| Datyl::Logger.err line, @env }
     halt 500, { 'Content-Type' => 'text/plain' }, "Internal Service Error.\n"   # ruby 1.9.3
  end
end

# Urg. The not_found RACK/sinatra method grabs *my* handled 404's [ halt(404), ... ] 
# in Sinatra 1.0.  We have to repeat the code above for this special case.

not_found  do
  e = @env['sinatra.error']
  message = if e.is_a? XmlResolution::Http404 
              e.client_message
            else
              "404 Not Found - #{request.url} doesn't exist.\n"
            end
  Datyl::Logger.warn message, @env
  content_type 'text/plain'
  message
end
