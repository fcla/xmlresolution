require 'uri'

module XmlResolution


  # Given a list of strings, first URI escape them, then join them with a space and
  # return the constructed string.

  def self.escape(*list)
    list.map{ |elt| URI.escape(elt) }.join(' ')
  end

  # Perform the inverse of the escape method.

  def self.unescape(string)
    data = string.split(/\s+/)
    data.map{ |elt| URI.unescape(elt) }
  end
  
end
