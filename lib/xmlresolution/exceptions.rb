module XmlResolution

  # these are 400-class errors:

  class XmlParseError < StandardError; end  # The xml parser complained bitterly.
  class LocationError < StandardError; end  # Bad schema location somehow - not http, too many redirects, etc.

  # these are 500-class errors:

  class ResolverError < StandardError; end   # General programming error in xmlresolver.rb  Can't happen.

end
