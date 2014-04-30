require 'puppet/ssl/base'
require 'puppet/ssl/certificate_signer'

# This class creates and manages X509 certificate signing requests.
#
# ## CSR attributes
#
# CSRs may contain a set of attributes that includes supplementary information
# about the CSR or information for the signed certificate.
#
# PKCS#9/RFC 2985 section 5.4 formally defines the "Challenge password",
# "Extension request", and "Extended-certificate attributes", but this
# implementation only handles the "Extension request" attribute. Other
# attributes may be defined on a CSR, but the RFC doesn't define behavior for
# any other attributes so we treat them as only informational.
#
# ## CSR Extension request attribute
#
# CSRs may contain an optional set of extension requests, which allow CSRs to
# include additional information that may be included in the signed
# certificate. Any additional information that should be copied from the CSR
# to the signed certificate MUST be included in this attribute.
#
# This behavior is dictated by PKCS#9/RFC 2985 section 5.4.2.
#
# @see http://tools.ietf.org/html/rfc2985 "RFC 2985 Section 5.4.2 Extension request"
#
class Puppet::SSL::CertificateRequest < Puppet::SSL::Base
  wraps OpenSSL::X509::Request

  extend Puppet::Indirector

  # If auto-signing is on, sign any certificate requests as they are saved.
  module AutoSigner
    def save(instance, key = nil)
      super

      # Try to autosign the CSR.
      if ca = Puppet::SSL::CertificateAuthority.instance
        ca.autosign(instance)
      end
    end
  end

  indirects :certificate_request, :terminus_class => :file, :extend => AutoSigner, :doc => <<DOC
    This indirection wraps an `OpenSSL::X509::Request` object, representing a certificate signing request (CSR).
    The indirection key is the certificate CN (generally a hostname).
DOC

  # Because of how the format handler class is included, this
  # can't be in the base class.
  def self.supported_formats
    [:s]
  end

  def extension_factory
    @ef ||= OpenSSL::X509::ExtensionFactory.new
  end

  # Create a certificate request with our system settings.
  #
  # @param key [OpenSSL::X509::Key, Puppet::SSL::Key] The key pair associated
  #   with this CSR.
  # @param options [Hash]
  # @option options [String] :dns_alt_names A comma separated list of
  #   Subject Alternative Names to include in the CSR extension request.
  # @option options [Hash<String, String, Array<String>>] :csr_attributes A hash
  #   of OIDs and values that are either a string or array of strings.
  # @option options [Array<String, String>] :extension_requests A hash of
  #   certificate extensions to add to the CSR extReq attribute, excluding
  #   the Subject Alternative Names extension.
  #
  # @raise [Puppet::Error] If the generated CSR signature couldn't be verified
  #
  # @return [OpenSSL::X509::Request] The generated CSR
  def generate(key, options = {})
    Puppet.info "Creating a new SSL certificate request for #{name}"

    # Support either an actual SSL key, or a Puppet key.
    key = key.content if key.is_a?(Puppet::SSL::Key)

    # If we're a CSR for the CA, then use the real ca_name, rather than the
    # fake 'ca' name.  This is mostly for backward compatibility with 0.24.x,
    # but it's also just a good idea.
    common_name = name == Puppet::SSL::CA_NAME ? Puppet.settings[:ca_name] : name

    csr = OpenSSL::X509::Request.new
    csr.version = 0
    csr.subject = OpenSSL::X509::Name.new([["CN", common_name]])
    csr.public_key = key.public_key

    if options[:csr_attributes]
      add_csr_attributes(csr, options[:csr_attributes])
    end

    if (ext_req_attribute = extension_request_attribute(options))
      csr.add_attribute(ext_req_attribute)
    end

    signer = Puppet::SSL::CertificateSigner.new
    signer.sign(csr, key)

    raise Puppet::Error, "CSR sign verification failed; you need to clean the certificate request for #{name} on the server" unless csr.verify(key.public_key)

    @content = csr
    Puppet.info "Certificate Request fingerprint (#{digest.name}): #{digest.to_hex}"
    @content
  end

  # Return the set of extensions requested on this CSR, in a form designed to
  # be useful to Ruby: an array of hashes.  Which, not coincidentally, you can pass
  # successfully to the OpenSSL constructor later, if you want.
  #
  # @return [Array<Hash{String => String}>] An array of two or three element
  # hashes, with key/value pairs for the extension's oid, its value, and
  # optionally its critical state.
  def request_extensions
    raise Puppet::Error, "CSR needs content to extract fields" unless @content

    # Prefer the standard extReq, but accept the Microsoft specific version as
    # a fallback, if the standard version isn't found.
    attribute   = @content.attributes.find {|x| x.oid == "extReq" }
    attribute ||= @content.attributes.find {|x| x.oid == "msExtReq" }
    return [] unless attribute

    extensions = unpack_extension_request(attribute)

    index = -1
    extensions.map do |ext_values|
      index += 1
      context = "#{attribute.oid} extension index #{index}"

      # OK, turn that into an extension, to unpack the content.  Lovely that
      # we have to swap the order of arguments to the underlying method, or
      # perhaps that the ASN.1 representation chose to pack them in a
      # strange order where the optional component comes *earlier* than the
      # fixed component in the sequence.
      case ext_values.length
      when 2
        ev = OpenSSL::X509::Extension.new(ext_values[0].value, ext_values[1].value)
        { "oid" => ev.oid, "value" => ev.value }

      when 3
        ev = OpenSSL::X509::Extension.new(ext_values[0].value, ext_values[2].value, ext_values[1].value)
        { "oid" => ev.oid, "value" => ev.value, "critical" => ev.critical? }

      else
        raise Puppet::Error, "In #{attribute.oid}, expected extension record #{index} to have two or three items, but found #{ext_values.length}"
      end
    end
  end

  def subject_alt_names
    @subject_alt_names ||= request_extensions.
      select {|x| x["oid"] == "subjectAltName" }.
      map {|x| x["value"].split(/\s*,\s*/) }.
      flatten.
      sort.
      uniq
  end

  # Return all user specified attributes attached to this CSR as a hash. IF an
  # OID has a single value it is returned as a string, otherwise all values are
  # returned as an array.
  #
  # The format of CSR attributes is specified in PKCS#10/RFC 2986
  #
  # @see http://tools.ietf.org/html/rfc2986 "RFC 2986 Certification Request Syntax Specification"
  #
  # @api public
  #
  # @return [Hash<String, String>]
  def custom_attributes
    x509_attributes = @content.attributes.reject do |attr|
      PRIVATE_CSR_ATTRIBUTES.include? attr.oid
    end

    x509_attributes.map do |attr|
      {"oid" => attr.oid, "value" => attr.value.first.value}
    end
  end

  private

  # Exclude OIDs that may conflict with how Puppet creates CSRs.
  #
  # We only have nominal support for Microsoft extension requests, but since we
  # ultimately respect that field when looking for extension requests in a CSR
  # we need to prevent that field from being written to directly.
  PRIVATE_CSR_ATTRIBUTES = [
    'extReq',   '1.2.840.113549.1.9.14',
    'msExtReq', '1.3.6.1.4.1.311.2.1.14',
  ]

  def add_csr_attributes(csr, csr_attributes)
    csr_attributes.each do |oid, value|
      begin
        if PRIVATE_CSR_ATTRIBUTES.include? oid
          raise ArgumentError, "Cannot specify CSR attribute #{oid}: conflicts with internally used CSR attribute"
        end

        encoded = OpenSSL::ASN1::PrintableString.new(value.to_s)

        attr_set = OpenSSL::ASN1::Set.new([encoded])
        csr.add_attribute(OpenSSL::X509::Attribute.new(oid, attr_set))
        Puppet.debug("Added csr attribute: #{oid} => #{attr_set.inspect}")
      rescue OpenSSL::X509::AttributeError => e
        raise Puppet::Error, "Cannot create CSR with attribute #{oid}: #{e.message}", e.backtrace
      end
    end
  end

  private

  PRIVATE_EXTENSIONS = [
    'subjectAltName', '2.5.29.17',
  ]

  # @api private
  def extension_request_attribute(options)
    extensions = []

    if options[:extension_requests]
      options[:extension_requests].each_pair do |oid, value|
        begin
          if PRIVATE_EXTENSIONS.include? oid
            raise Puppet::Error, "Cannot specify CSR extension request #{oid}: conflicts with internally used extension request"
          end

          ext = OpenSSL::X509::Extension.new(oid, value.to_s, false)
          extensions << ext
        rescue OpenSSL::X509::ExtensionError => e
          raise Puppet::Error, "Cannot create CSR with extension request #{oid}: #{e.message}", e.backtrace
        end
      end
    end

    if options[:dns_alt_names]
      names = options[:dns_alt_names].split(/\s*,\s*/).map(&:strip) + [name]
      names = names.sort.uniq.map {|name| "DNS:#{name}" }.join(", ")
      alt_names_ext = extension_factory.create_extension("subjectAltName", names, false)

      extensions << alt_names_ext
    end

    unless extensions.empty?
      seq = OpenSSL::ASN1::Sequence(extensions)
      ext_req = OpenSSL::ASN1::Set([seq])
      OpenSSL::X509::Attribute.new("extReq", ext_req)
    end
  end

  # Unpack the extReq attribute into an array of Extensions.
  #
  # The extension request attribute is structured like
  # `Set[Sequence[Extensions]]` where the outer Set only contains a single
  # sequence.
  #
  # In addition the Ruby implementation of ASN1 requires that all ASN1 values
  # contain a single value, so Sets and Sequence have to contain an array
  # that in turn holds the elements. This is why we have to unpack an array
  # every time we unpack a Set/Seq.
  #
  # @see http://tools.ietf.org/html/rfc2985#ref-10 5.4.2 CSR Extension Request structure
  # @see http://tools.ietf.org/html/rfc5280 4.1 Certificate Extension structure
  #
  # @api private
  #
  # @param attribute [OpenSSL::X509::Attribute] The X509 extension request
  #
  # @return [Array<Array<Object>>] A array of arrays containing the extension
  #   OID the critical state if present, and the extension value.
  def unpack_extension_request(attribute)

    unless attribute.value.is_a? OpenSSL::ASN1::Set
      raise Puppet::Error, "In #{attribute.oid}, expected Set but found #{attribute.value.class}"
    end

    unless attribute.value.value.is_a? Array
      raise Puppet::Error, "In #{attribute.oid}, expected Set[Array] but found #{attribute.value.value.class}"
    end

    unless attribute.value.value.size == 1
      raise Puppet::Error, "In #{attribute.oid}, expected Set[Array] with one value but found #{attribute.value.value.size} elements"
    end

    unless attribute.value.value.first.is_a? OpenSSL::ASN1::Sequence
      raise Puppet::Error, "In #{attribute.oid}, expected Set[Array[Sequence[...]]], but found #{extension.class}"
    end

    unless attribute.value.value.first.value.is_a? Array
      raise Puppet::Error, "In #{attribute.oid}, expected Set[Array[Sequence[Array[...]]]], but found #{extension.value.class}"
    end

    extensions = attribute.value.value.first.value

    extensions.map(&:value)
  end
end
