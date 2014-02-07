require 'puppet/ssl/base'
require 'puppet/indirector'

# Manage the CRL.
class Puppet::SSL::CertificateRevocationList < Puppet::SSL::Base
  FIVE_YEARS = 5 * 365*24*60*60

  wraps OpenSSL::X509::CRL

  extend Puppet::Indirector
  indirects :certificate_revocation_list, :terminus_class => :file, :doc => <<DOC
    This indirection wraps an `OpenSSL::X509::CRL` object, representing a certificate revocation list (CRL).
    The indirection key is the CA name (usually literally `ca`).
DOC

  # Convert a string into an instance.
  def self.from_s(string)
    super(string, 'foo') # The name doesn't matter
  end

  # Because of how the format handler class is included, this
  # can't be in the base class.
  def self.supported_formats
    [:s]
  end

  # Knows how to create a CRL with our system defaults.
  def generate(cert, cakey)
    Puppet.info "Creating a new certificate revocation list"

    create_crl_issued_by(cert)
    start_at_initial_crl_number
    update_valid_time_range_to_start_at(Time.now)
    sign_with(cakey)

    @content
  end

  # The name doesn't actually matter; there's only one CRL.
  # We just need the name so our Indirector stuff all works more easily.
  def initialize(fakename)
    @name = "crl"
  end

  # Revoke the certificate with serial number SERIAL issued by this
  # CA, then write the CRL back to disk. The REASON must be one of the
  # OpenSSL::OCSP::REVOKED_* reasons
  def revoke(serial, cakey, reason = OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE)
    Puppet.notice "Revoked certificate with serial #{serial}"
    time = Time.now

    add_certificate_revocation_for(serial, reason, time)
    update_to_next_crl_number
    update_valid_time_range_to_start_at(time)
    sign_with(cakey)

    Puppet::SSL::CertificateRevocationList.indirection.save(self)
  end

private

  def create_crl_issued_by(cert)
    ef = OpenSSL::X509::ExtensionFactory.new(cert)
    @content = wrapped_class.new
    @content.issuer = cert.subject
    @content.add_extension(ef.create_ext("authorityKeyIdentifier", "keyid:always"))
    @content.version = 1
  end

  def start_at_initial_crl_number
    @content.add_extension(crl_number_of(0))
  end

  def add_certificate_revocation_for(serial, reason, time)
    revoked = OpenSSL::X509::Revoked.new
    revoked.serial = serial
    revoked.time = time
    enum = OpenSSL::ASN1::Enumerated(reason)
    ext = OpenSSL::X509::Extension.new("CRLReason", enum)
    revoked.add_extension(ext)
    @content.add_revoked(revoked)
  end

  def update_valid_time_range_to_start_at(time)
    # The CRL is not valid if the time of checking == the time of last_update.
    # So to have it valid right now we need to say that it was updated one second ago.
    @content.last_update = time - 1
    @content.next_update = time + FIVE_YEARS
  end

  def update_to_next_crl_number
    @content.extensions = with_next_crl_number_from(@content.extensions)
  end

  def with_next_crl_number_from(existing_extensions)
    existing_crl_num = existing_extensions.find { |e| e.oid == 'crlNumber' }
    new_crl_num = existing_crl_num ? existing_crl_num.value.to_i + 1 : 0

    extensions_without_crl_num = existing_extensions.reject { |e| e.oid == 'crlNumber' }
    extensions_without_crl_num + [crl_number_of(new_crl_num)]
  end

  def crl_number_of(number)
    OpenSSL::X509::Extension.new('crlNumber', OpenSSL::ASN1::Integer(number))
  end

  def sign_with(cakey)
    @content.sign(cakey, OpenSSL::Digest::SHA1.new)
  end
end
