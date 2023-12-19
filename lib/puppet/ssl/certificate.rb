# frozen_string_literal: true
require_relative '../../puppet/ssl/base'

# Manage certificates themselves.  This class has no
# 'generate' method because the CA is responsible
# for turning CSRs into certificates; we can only
# retrieve them from the CA (or not, as is often
# the case).
#
# @deprecated Use {Puppet::SSL::SSLProvider} instead.
class Puppet::SSL::Certificate < Puppet::SSL::Base
  # This is defined from the base class
  wraps OpenSSL::X509::Certificate

  # Because of how the format handler class is included, this
  # can't be in the base class.
  def self.supported_formats
    [:s]
  end

  def self.subject_alt_names_for(cert)
    alts = cert.extensions.find{|ext| ext.oid == "subjectAltName"}
    return [] unless alts

    alts.value.split(/\s*,\s*/)
  end

  def subject_alt_names
    self.class.subject_alt_names_for(content)
  end

  def expiration
    return nil unless content

    content.not_after
  end

  # This name is what gets extracted from the subject before being passed
  # to the constructor, so it's not downcased
  def unmunged_name
    self.class.name_from_subject(content.subject.to_utf8)
  end

  # Any extensions registered with custom OIDs as defined in module
  # Puppet::SSL::Oids may be looked up here.
  #
  # A cert with a 'pp_uuid' extension having the value 'abcd' would return:
  #
  # [{ 'oid' => 'pp_uuid', 'value' => 'abcd'}]
  #
  # @return [Array<Hash{String => String}>] An array of two element hashes,
  # with key/value pairs for the extension's oid, and its value.
  def custom_extensions
    custom_exts = content.extensions.select do |ext|
      Puppet::SSL::Oids.subtree_of?('ppRegCertExt', ext.oid) or
        Puppet::SSL::Oids.subtree_of?('ppPrivCertExt', ext.oid) or
        Puppet::SSL::Oids.subtree_of?('ppAuthCertExt', ext.oid)
    end

    custom_exts.map do |ext|
      {'oid' => ext.oid, 'value' => get_ext_val(ext.oid)}
    end
  end

  private


  # Extract the extensions sequence from the wrapped certificate's raw ASN.1 form
  def exts_seq
    # See RFC-2459 section 4.1 (https://tools.ietf.org/html/rfc2459#section-4.1)
    # to see where this is defined. Essentially this is saying "in the first
    # sequence in the certificate, find the item that's tagged with 3. This
    # is where the extensions are stored."
    @extensions_tag ||= 3

    @exts_seq ||= OpenSSL::ASN1.decode(content.to_der).value[0].value.find do |data|
      (data.tag == @extensions_tag) && (data.tag_class == :CONTEXT_SPECIFIC)
    end.value[0]
  end

  # Get the DER parsed value of an X.509 extension by it's OID, or short name
  # if one has been registered with OpenSSL.
  def get_ext_val(oid)
    ext_obj = exts_seq.value.find do |ext_seq|
      ext_seq.value[0].value == oid
    end

    raw_val = ext_obj.value.last.value

    begin
      OpenSSL::ASN1.decode(raw_val).value
    rescue OpenSSL::ASN1::ASN1Error
      # This is required to maintain backward compatibility with the previous
      # way trusted facts were signed. See PUP-3560
      raw_val
    end
  end

end
