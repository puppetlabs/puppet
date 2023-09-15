require 'spec_helper'

describe Puppet::SSL::CertificateSigner do
  include PuppetSpec::Files

  let(:wrong_key) { OpenSSL::PKey::RSA.new(512) }
  let(:client_cert) { cert_fixture('signed.pem') }

  # jruby-openssl >= 0.13.0 (JRuby >= 9.3.5.0) raises an error when signing a
  # certificate when there is a discrepancy between the certificate and key.
  it 'raises if client cert signature is invalid', if: Puppet::Util::Platform.jruby? && RUBY_VERSION.to_f >= 2.6 do
    expect {
      client_cert.sign(wrong_key, OpenSSL::Digest::SHA256.new)
    }.to raise_error(OpenSSL::X509::CertificateError,
                     'invalid public key data')
  end
end
