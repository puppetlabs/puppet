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
        ca.autosign(instance.name)
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
  # @param opts [Hash]
  # @options opts [String] :dns_alt_names A comma separated list of
  #   Subject Alternative Names to include in the CSR extension request.
  # @options opts [Hash<String, String, Array<String>>] :csr_attributes A hash
  #   of OIDs and values that are either a string or array of strings.
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

    if options[:dns_alt_names] then
      names = options[:dns_alt_names].split(/\s*,\s*/).map(&:strip) + [name]
      names = names.sort.uniq.map {|name| "DNS:#{name}" }.join(", ")
      names = extension_factory.create_extension("subjectAltName", names, false)

      extReq = OpenSSL::ASN1::Set([OpenSSL::ASN1::Sequence([names])])

      # We only support the standard request extensions.  If you really need
      # msExtReq support, let us know and we can restore them. --daniel 2011-10-10
      csr.add_attribute(OpenSSL::X509::Attribute.new("extReq", extReq))
    end

    signer = Puppet::SSL::CertificateSigner.new
    signer.sign(csr, key)

    raise Puppet::Error, "CSR sign verification failed; you need to clean the certificate request for #{name} on the server" unless csr.verify(key.public_key)

    @content = csr
    Puppet.info "Certificate Request fingerprint (#{digest.name}): #{digest.to_hex}"
    @content
  end

  # Return the set of extensions requested on this CSR, in a form designed to
  # be useful to Ruby: a hash.  Which, not coincidentally, you can pass
  # successfully to the OpenSSL constructor later, if you want.
  def request_extensions
    raise Puppet::Error, "CSR needs content to extract fields" unless @content

    # Prefer the standard extReq, but accept the Microsoft specific version as
    # a fallback, if the standard version isn't found.
    ext = @content.attributes.find {|x| x.oid == "extReq" } or
      @content.attributes.find {|x| x.oid == "msExtReq" }
    return [] unless ext

    # Assert the structure and extract the names into an array of arrays.
    unless ext.value.is_a? OpenSSL::ASN1::Set
      raise Puppet::Error, "In #{ext.oid}, expected Set but found #{ext.value.class}"
    end

    unless ext.value.value.is_a? Array
      raise Puppet::Error, "In #{ext.oid}, expected Set[Array] but found #{ext.value.value.class}"
    end

    unless ext.value.value.length == 1
      raise Puppet::Error, "In #{ext.oid}, expected Set[Array[...]], but found #{ext.value.value.length} items in the array"
    end

    san = ext.value.value.first
    unless san.is_a? OpenSSL::ASN1::Sequence
      raise Puppet::Error, "In #{ext.oid}, expected Set[Array[Sequence[...]]], but found #{san.class}"
    end
    san = san.value

    # OK, now san should be the array of items, validate that...
    index = -1
    san.map do |name|
      index += 1

      unless name.is_a? OpenSSL::ASN1::Sequence
        raise Puppet::Error, "In #{ext.oid}, expected request extension record #{index} to be a Sequence, but found #{name.class}"
      end
      name = name.value

      # OK, turn that into an extension, to unpack the content.  Lovely that
      # we have to swap the order of arguments to the underlying method, or
      # perhaps that the ASN.1 representation chose to pack them in a
      # strange order where the optional component comes *earlier* than the
      # fixed component in the sequence.
      case name.length
      when 2
        ev = OpenSSL::X509::Extension.new(name[0].value, name[1].value)
        { "oid" => ev.oid, "value" => ev.value }

      when 3
        ev = OpenSSL::X509::Extension.new(name[0].value, name[2].value, name[1].value)
        { "oid" => ev.oid, "value" => ev.value, "critical" => ev.critical? }

      else
        raise Puppet::Error, "In #{ext.oid}, expected extension record #{index} to have two or three items, but found #{name.length}"
      end
    end.flatten
  end

  def subject_alt_names
    @subject_alt_names ||= request_extensions.
      select {|x| x["oid"] = "subjectAltName" }.
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
  # @return [Hash<String, <String, Array<String>>]
  def custom_attributes
    x509_attributes = @content.attributes.reject do |attr|
      PRIVATE_CSR_ATTRIBUTES.include? attr.oid
    end

    x509_attributes.map do |attr|
      oid = attr.oid

      attr_values = attr.value.first.value.map { |os| os.value }
      value = attr_values.size > 1 ? attr_values : attr_values.first

      {"oid" => attr.oid, "value" => value}
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
    csr_attributes.each do |oid, values|
      if PRIVATE_CSR_ATTRIBUTES.include? oid
        raise ArgumentError, "Cannot specify CSR attribute #{oid}: conflicts with internally used CSR attribute"
      end

      encoded_strings = Array(values).map { |value| OpenSSL::ASN1::OctetString.new(value.to_s) }
      attr_set = OpenSSL::ASN1::Set.new([OpenSSL::ASN1::Sequence.new(encoded_strings)])
      csr.add_attribute(OpenSSL::X509::Attribute.new(oid, attr_set))
      Puppet.debug("Added csr attribute: #{oid} => #{attr_set.inspect}")
    end
  end
end
