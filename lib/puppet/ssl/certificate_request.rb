require 'puppet/ssl/base'

# Manage certificate requests.
class Puppet::SSL::CertificateRequest < Puppet::SSL::Base
  wraps OpenSSL::X509::Request

  extend Puppet::Indirector

  # If auto-signing is on, sign any certificate requests as they are saved.
  module AutoSigner
    def save(instance, key = nil)
      super

      # Try to autosign the CSR.
      if ca = Puppet::SSL::CertificateAuthority.instance
        ca.autosign
      end
    end
  end

  indirects :certificate_request, :terminus_class => :file, :extend => AutoSigner

  # Convert a string into an instance.
  def self.from_s(string)
    instance = wrapped_class.new(string)
    name = instance.subject.to_s.sub(/\/CN=/i, '').downcase
    result = new(name)
    result.content = instance
    result
  end

  # Because of how the format handler class is included, this
  # can't be in the base class.
  def self.supported_formats
    [:s]
  end

  def extension_factory
    @ef ||= OpenSSL::X509::ExtensionFactory.new
  end

  # How to create a certificate request with our system defaults.
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

    if options[:dns_alt_names] then
      names = options[:dns_alt_names].split(/\s*,\s*/).map(&:strip) + [name]
      names = names.sort.uniq.map {|name| "DNS:#{name}" }.join(", ")
      names = extension_factory.create_extension("subjectAltName", names, false)

      extReq = OpenSSL::ASN1::Set([OpenSSL::ASN1::Sequence([names])])

      # We only support the standard request extensions.  If you really need
      # msExtReq support, let us know and we can restore them. --daniel 2011-10-10
      csr.add_attribute(OpenSSL::X509::Attribute.new("extReq", extReq))
    end

    csr.sign(key, OpenSSL::Digest::MD5.new)

    raise Puppet::Error, "CSR sign verification failed; you need to clean the certificate request for #{name} on the server" unless csr.verify(key.public_key)

    @content = csr
    Puppet.info "Certificate Request fingerprint (md5): #{fingerprint}"
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
end
