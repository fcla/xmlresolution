module XmlResolution

  class XmlResolutionError < StandardError; end

    # Bad schema location somehow - not http, too many redirects.  Should be entirely fielded within our classes.

    class LocationError < XmlResolutionError; end  

    # User errors (ulitmately)

    class Http400Error < XmlResolutionError; end

       # The xml parser complained, bitterly. Expected when a non-XML file is submitted.

       class XmlParseError < Http400Error; end     

       # Requestor supplied an invalid name for a collection.

       class CollectionNameError < Http400Error; end     
       
       # We needed a filename to be submitted, but alas.

       class MissingFilenameError < Http400Error; end     
       
    # System errors

    class Http500Error < XmlResolutionError; end

       # General fatal errors

       class ResolverError                 < Http500Error; end
       class CollectionInitializationError < Http500Error; end
       class LockError                     < Http500Error; end
  
end
