require 'puppet/ssl/base'
require 'puppet/ssl/ocsp'

# This represents an OCSP request
class Puppet::SSL::Ocsp::Request < Puppet::SSL::Base
  wraps OpenSSL::OCSP::Request

  extend Puppet::Indirector
  indirects :ocsp, :terminus_class => :ca

  # Convert a der encoded request into an instance.
  # String serialization for OCSP requests results into
  # a DER encoded string
  def self.from_s(string)
    instance = wrapped_class.new(string)
    result = new("n/a")
    result.content = instance
    result
  end

  # Convert our thing to der.
  def to_s
    return "" unless content
    content.to_der
  end

  def self.supported_formats
    [:s]
  end

  def generate(cert_to_check, certificate, key, ca)
    cert_to_check = cert_to_check.content if cert_to_check.is_a?(Puppet::SSL::Certificate)
    certificate = certificate.content if certificate.is_a?(Puppet::SSL::Certificate)
    ca = ca.host.certificate if ca.is_a?(Puppet::SSL::CertificateAuthority)
    ca = ca.content if ca.is_a?(Puppet::SSL::Certificate)
    key = key.content if key.respond_to?(:content)

    @content = OpenSSL::OCSP::Request.new
    cid = OpenSSL::OCSP::CertificateId.new(cert_to_check, ca)
    @content.add_certid(cid)
    @content.add_nonce
    @content.sign(certificate, key, []) if certificate and key
    self
  end
end
