module XmlResolution

  # Most named exceptions in the XmlResolution service we subclass here
  # to one of the HTTP classes.  Libraries are designed specifically
  # to be unaware of this mapping: they only use their specific low level
  # exceptions classes.
  #
  # In general, if we catch an HttpError at our top level app, we can
  # blindly return the error message to the client as a diagnostic,
  # and log it.  The fact that we're naming these exceptions means
  # we're being careful not to leak information, and still be helpful
  # to the Client.  They are very specific messages; tracebacks will
  # not be required.
  #
  # When we get an un-named exception, however, the appropriate thing
  # to do is to just supply a very terse message to the client (e.g.,
  # we wouldn't like to expose errors from an ORM that said something
  # like "password 'topsecret' failed in mysql open").  We *will* want
  # to log the full error message, and probably a backtrace to boot.

  class HttpError < StandardError;
    def client_message
      "#{status_code} #{status_text} - #{message.chomp('.')}."
    end
  end

  # Most of the following comments are pretty darn obvious - they
  # are included for easy navigation in the generated rdoc html files.

  # Http400Error's group named exceptions as something the client did
  # wrong. It is subclassed from the HttpError exception.

  class Http400Error < HttpError;  end

  # Http400 exception: 400 Bad Request - it is subclassed from Http400Error.

  class Http400 < Http400Error
    def status_code; 400; end
    def status_text; "Bad Request"; end
  end

  # Http401 exception: 401 Unauthorized - it is subclassed from Http400Error.

  class Http401 < Http400Error
    def status_code; 401; end
    def status_text; "Unauthorized"; end
  end

  # Http403 exception: 403 Forbidden - it is subclassed from Http400Error.

  class Http403 < Http400Error
    def status_code; 403; end
    def status_text; "Forbidden"; end
  end

  # Http404 exception:  404 Not Found - it is subclassed from Http400Error.

  class Http404 < Http400Error
    def status_code; 404; end
    def status_text; "Not Found"; end
  end

  # Http405 exception: 405 Method Not Allowed - it is subclassed from Http400Error.

  class Http405 < Http400Error
    def status_code; 405; end
    def status_text; "Method Not Allowed"; end
  end

  # Http406 exception: 406 Not Acceptable - it is subclassed from Http400Error.

  class Http406 < Http400Error
    def status_code; 406; end
    def status_text; "Not Acceptable"; end
  end

  # Http408 exception: 408 Request Timeout - it is subclassed from Http400Error.

  class Http408 < Http400Error
    def status_code; 408; end
    def status_text; "Request Timeout"; end
  end

  # Http409 exception: 409 Conflict - it is subclassed from Http400Error.

  class Http409 < Http400Error
    def status_code; 409; end
    def status_text; "Conflict"; end
  end

  # Http410 exception: 410 Gone - it is subclassed from Http400Error.

  class Http410 < Http400Error
    def status_code; 410; end
    def status_text; "Gone"; end
  end

  # Http411 exception: 411 Length Required - it is subclassed from Http400Error.

  class Http411 < Http400Error
    def status_code; 411; end
    def status_text; "Length Required"; end
  end

  # Http412 exception: 412 Precondition Failed - it is subclassed from Http400Error.

  class Http412 < Http400Error
    def status_code; 412; end
    def status_text; "Precondition Failed"; end
  end

  # Http413 exception: 413 Request Entity Too Large - it is subclassed from Http400Error.

  class Http413 < Http400Error
    def status_code; 413; end
    def status_text; "Request Entity Too Large"; end
  end

  # Http414 exception: 414 Request-URI Too Long - it is subclassed from Http400Error.

  class Http414 < Http400Error
    def status_code; 414; end
    def status_text; "Request-URI Too Long"; end
  end

  # Http415 exception: 415 Unsupported Media Type - it is subclassed from Http400Error.

  class Http415 < Http400Error
    def status_code; 415; end
    def status_text; "Unsupported Media Type"; end
  end

  # Http500Error's group errors that are the server's fault.
  # It is subclassed from the HttpError exception.

  class Http500Error < HttpError;  end

  # Http500 exception: 500 Internal Service Error - it is subclassed from Http500Error.

  class Http500 < Http500Error
    def status_code; 500; end
    def status_text; "Internal Service Error"; end
  end

  # Http501 exception: 501 Not Implemented - it is subclassed from Http500Error.

  class Http501 < Http500Error
    def status_code; 501; end
    def status_text; "Not Implemented"; end
  end

  # Http503 exception: 503 Service Unavailable - it is subclassed from Http500Error.

  class Http503 < Http500Error
    def status_code; 503; end
    def status_text; "Service Unavailable"; end
  end

  # Http505 exception: 505 HTTP Version Not Supported - it is subclassed from Http500Error.

  class Http505 < Http500Error
    def status_code; 505; end
    def status_text; "HTTP Version Not Supported"; end
  end
  
  # BadXmlDocument exception, client's fault (subclasses Http400): Instance document could not be parsed..

  class BadXmlDocument      < Http415; end            

  # BadBadXmlDocument exception, client's fault (subclasses BadXmlDocument): ..it *really* could not be parsed

  class BadBadXmlDocument   < BadXmlDocument; end     

  # InadequateDataError exception, client's fault (subclasses Http400): Problem with uploaded data (e.g. length 0)

  class InadequateDataError < Http400; end            

  # BadCollectionID exception, client's fault (subclasses Http400): PUT of a Collection ID wasn't suitable

  class BadCollectionID     < Http400; end            

  # BadXmlVersion exception, client's fault (subclasses Http415): Unsupported XML version (only 1.0)

  class BadXmlVersion       < Http415; end            

  # TooManyDarnSchemas exception, client's fault (subclasses Http400): Possible denial of service - infinite train of schemas

  class TooManyDarnSchemas  < Http400; end            



  # LockError exception, server's fault (subclasses Http500): Timed out trying to get a locked file

  class LockError           < Http500; end            

  # ConfigurationError exception, server's fault (subclasses Http500): Something wasn't set up correctly

  class ConfigurationError  < Http500; end            

  # ResolverError exception, server's fault (subclasses Http500): Result of a programming error

  class ResolverError       < Http500; end            

  # The LocationError is caught internally, and is used to indicate that
  # the fetch of a Schema could not be performed because the location
  # URL scheme was not supported.  This results in reporting broken
  # link, and is normally not very important: there are many other
  # schemas to report on.
  #
  # However, if this exception was raised to the top level, we do
  # not want to pass the information to the user.  That's why it is not
  # assigned to an HttpError subclass - we *want* a logged backtrace in
  # that case.

  class LocationError < StandardError; end

end # of module
