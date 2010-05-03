require 'uri'
require 'socket'
require 'ostruct'
require 'xmlresolution/exceptions'


module XmlResolution

  # Return a struct giving all sorts of good information on the version of this
  # service.  TODO: get the good information.

  def self.version
    version_label = '0.9.2'
    os = OpenStruct.new("label"   => version_label,
                        "uri"     => "info:fcla/daitss/xmlresolution/#{version_label}",
                        "note"    => "we'll put additional version information here"
                        )
    def os.to_s
      self.label
    end
    os
  end


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

  # utf8 ensures we won't smash the current value of KCODE

  def self.utf8
    the_value_formerly_known_as_kcode = $KCODE
    $KCODE = 'UTF8'
    yield
  ensure
    $KCODE = the_value_formerly_known_as_kcode
  end

  # Our hostname. Or one of them, at least.

  def self.hostname
    Socket::gethostname.downcase
  end

  # Given an XmlResolver (or XmlResolverReloaded) object XREZ, and an
  # URI AGENT, make a PREMIS style event report for the outcome of the
  # resolution of one XML document.  While XmlResolver#filename and
  # XmlResolver#local_uri are not required to be set by the
  # XmlResolver object, we do require them to have been set somewhere
  # along the line if we are going to write this kind of PREMIS
  # report.

  def self.xml_resolver_report xrez

    $KCODE =~ /UTF8/ or raise ResolverError, "Ruby $KCODE == #{$KCODE}, but it must be UTF-8"
    xrez.filename    or raise MissingFilenameError, "Can't find submittor's assigned filename when attempting to write the PREMIS resolution report for a submitted XML document."
    xrez.local_uri   or raise ResolverError, "Can't determing the local file URI for the submitted XML document #{xrez.filename} when attempting to write the PREMIS resolution report."

    successes = failures = 0
    xrez.schemas.each do |s|
      successes += 1 if s.status == :success
      failures  += 1 if s.status != :success
    end

    if (successes > 0 and failures > 0)
      outcome = 'mixed'
    elsif failures > 0
      outcome = 'failure'
    else
      outcome = 'success'  # vacuous case is success
    end

    xml = Builder::XmlMarkup.new(:indent => 2)

    xml.instruct!(:xml, :encoding => 'UTF-8')  # well, if $KCODE  was set correctly

    xml.premis('xmlns'     => 'info:lc/xmlns/premis-v2',
               'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
               'version'   => '2.0') {
      xml.event {
        xml.eventIdentifier {
          xml.eventIdentifierType('URI')
          xml.eventIdentifierValue(xrez.local_uri) # typically this is only used as a placeholder
        }                                          # and will be re-written.
        xml.eventType('XML Resolution')
        xml.eventDateTime(xrez.datetime.xmlschema)
        xml.eventOutcomeInformation { 
          xml.eventOutcome(outcome) 
          xml.eventOutcomeDetail {
            xml.eventOutcomeDetailExtension {
              xrez.schemas.each { |s| xml.broken_link(s.location) unless s.status == :success } # note only schemas that can't be downloaded
              xrez.unresolved_namespaces.each { |ns| xml.unresolved_namespace(ns) }
            }
          }
        }
        xml.linkingAgentIdentifier {
          xml.linkingAgentIdentifierType('URI')
          xml.linkingAgentIdentifierValue(version.uri)
        }
        xml.linkingObjectIdentifier {
          xml.linkingObjectIdentifierType('URI')
          xml.linkingObjectIdentifierValue(xrez.filename)
        }
      }
      xml.agent {
        xml.agentIdentifer {
          xml.agentIdentiferType('URI')
          xml.agentIdentiferValue(version.uri)    # info uri that includes version
        }
        xml.agentName('XML Resolution Service')
        xml.agentType('Web Service')
        xml.agentNote(version.note)               # details associated with the info version
      }
    }
    xml.target!
  end
end
