module XmlResolution

  # Most named exceptions we assign to one of the HTTP classes.  In
  # general, if we catch an HttpError, we can pretty much blindly return
  # the error message to the client as a diagnostic, and log it.  The
  # fact that we're naming these exceptions means we're being careful
  # not to leak information, and still be helpful to the Client's
  # driver.  They are very specific messages.
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

  class Http400Error < HttpError;  end

  class Http400 < Http400Error
    def status_code; 400; end
    def status_text; "Bad Request"; end
  end

  class Http401 < Http400Error
    def status_code; 401; end
    def status_text; "Unauthorized"; end
  end

  class Http403 < Http400Error
    def status_code; 403; end
    def status_text; "Forbidden"; end
  end

  class Http404 < Http400Error
    def status_code; 404; end
    def status_text; "Not Found"; end
  end

  class Http405 < Http400Error
    def status_code; 405; end
    def status_text; "Method Not Allowed"; end
  end

  class Http406 < Http400Error
    def status_code; 406; end
    def status_text; "Not Acceptable"; end
  end

  class Http408 < Http400Error
    def status_code; 408; end
    def status_text; "Request Timeout"; end
  end

  class Http409 < Http400Error
    def status_code; 409; end
    def status_text; "Conflict"; end
  end

  class Http410 < Http400Error
    def status_code; 410; end
    def status_text; "Gone"; end
  end

  class Http411 < Http400Error
    def status_code; 411; end
    def status_text; "Length Required"; end
  end

  class Http412 < Http400Error
    def status_code; 412; end
    def status_text; "Precondition Failed"; end
  end

  class Http413 < Http400Error
    def status_code; 413; end
    def status_text; "Request Entity Too Large"; end
  end

  class Http414 < Http400Error
    def status_code; 414; end
    def status_text; "Request-URI Too Long"; end
  end

  class Http415 < Http400Error
    def status_code; 415; end
    def status_text; "Unsupported Media Type"; end
  end

  class Http500Error < HttpError;  end

  class Http500 < Http500Error
    def status_code; 500; end
    def status_text; "Internal Service Error"; end
  end

  class Http501 < Http500Error
    def status_code; 501; end
    def status_text; "Not Implemented"; end
  end

  class Http503 < Http500Error
    def status_code; 503; end
    def status_text; "Service Unavailable"; end
  end

  class Http505 < Http500Error
    def status_code; 505; end
    def status_text; "HTTP Version Not Supported"; end
  end

  # Client's fault:

  class BadXmlDocument      < Http400; end            # could not be parsed
  class BadBadXmlDocument   < BadXmlDocument; end     # *really* could not be parsed
  class InadequateDataError < Http400; end            # Problem with uploaded data (e.g. length 0)
  class BadCollectionID     < Http400; end            # PUT of a Collection ID wasn't suitable
  class BadXmlVersion       < Http415; end            # Unsupported XML version (only 1.0)

  # Server's fault:

  class LockError           < Http500; end            # Timed out trying to get a locked file
  class ConfigurationError  < Http500; end            # Something wasn't set up correctly
  class ResolverError       < Http500; end            # Result of a programming error

  # LocationError is caught internally, and is used to indicate that
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
