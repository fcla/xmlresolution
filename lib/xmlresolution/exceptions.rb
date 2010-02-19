module XmlResolution

  class XmlResolutionError < StandardError; end

    # Bad schema location somehow - not http, too many redirects.  Should be entirely fielded within our classes.

    class LocationError < XmlResolutionError; end  

    # User errors

    class Http400Error < XmlResolutionError; end

       # The xml parser complained, bitterly.

       class XmlParseError < Http400Error; end     

    # System errors

    class Http500Error < XmlResolutionError; end

       # general fatal errors

       class ResolverError                 < Http500Error; end
       class CollectionInitializationError < Http500Error; end
       class LockError                     < Http500Error; end

end
