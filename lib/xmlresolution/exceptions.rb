module XmlResolution

  class XmlResolutionError < StandardError; end

    # There was a bad schema location somehow - not an HTTP scheme, too many redirects.  This 
    # class of errors should be entirely fielded within our classes, never percolating up to
    # top level:

    class LocationError < XmlResolutionError; end

    # The following are ultimately client errors, and are here grouped together under Http400Error.

    class Http400Error < XmlResolutionError; end

       # The xml parser complained, bitterly. Expected when a non-XML file or an invalid XML file is submitted.

       class XmlParseError < Http400Error; end

       # Requestor supplied an invalid name for a collection.

       class CollectionNameError < Http400Error; end

       # We needed a filename to be submitted, but alas, it was not.

       class MissingFilenameError < Http400Error; end

    # System errors we catch are grouped together under Http500Error's.

    class Http500Error < XmlResolutionError; end

       # General fatal errors

       class ResolverError                 < Http500Error; end
       class CollectionInitializationError < Http500Error; end
       class LockError                     < Http500Error; end

end
