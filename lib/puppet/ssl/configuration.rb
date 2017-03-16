require 'puppet/ssl'
require 'openssl'
module Puppet
module SSL
  # Puppet::SSL::Configuration is intended to separate out the following concerns:
  # * CA certificates that authenticate peers (ca_auth_file)
  # * Who clients trust as distinct from who servers trust.  We should not
  #   assume one single self signed CA cert for everyone.
class Configuration

  # Construct a default configuration based on the Puppet client SSL settings.
  # @return [Puppet::SSL::Configuration]
  def self.default
    new(Puppet[:localcacert], {ca_auth_file: Puppet[:ssl_client_ca_auth]})
  end

  # @param localcacert [String] The path to the local CA certificate
  # @param options [Hash] Additional options for the current SSL configuration
  #
  # @option options [String, nil] :ca_auth_file The path to an optional bundle
  #   of CA certificates that the agent should trust when performing SSL
  #   peer verification.
  # @return [void]
  def initialize(localcacert, options={})
    @localcacert = localcacert
    @ca_auth_file = options[:ca_auth_file]
  end

  # @deprecated Use {#ca_auth_file} instead.
  def ca_chain_file
    ca_auth_file
  end

  # The ca_auth_file method is intended to return the PEM bundle of CA certs
  # used to authenticate peer connections.
  def ca_auth_file
    @ca_auth_file || @localcacert
  end

  ##
  # ca_auth_certificates returns an Array of OpenSSL::X509::Certificate
  # instances intended to be used in the connection verify_callback.  This
  # method loads and parses the {#ca_auth_file} from the filesystem.
  #
  # @api private
  #
  # @return [Array<OpenSSL::X509::Certificate>]
  def ca_auth_certificates
    @ca_auth_certificates ||= decode_cert_bundle(read_file(ca_auth_file))
  end

  # Generate an SSL store configured with our trusted CA certificates, and add our CRL if
  # certificate revocation is enabled.
  #
  # @param options [Hash] Configuration options for the SSL store
  #
  # @option options [Integer] :purpose The OpenSSL store purpose
  # @option options [true, false] :use_crl Whether CRL checking should be enabled
  #
  # @return [OpenSSL::X509::Store]
  def ssl_store(options = {})
    use_crl = options.fetch(:use_crl, Puppet.lookup(:certificate_revocation))
    purpose = options.fetch(:purpose, OpenSSL::X509::PURPOSE_ANY)
    store = OpenSSL::X509::Store.new
    store.purpose = purpose

    store.add_file(ca_auth_file)

    # If we're doing revocation and there's a CRL, add it to our store.
    if use_crl
      if crl = Puppet::SSL::CertificateRevocationList.indirection.find(Puppet::SSL::Host::CA_NAME)
        store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK
        store.add_crl(crl.content)
      end
    end

    store
  end

  ##
  # Decode a string of concatenated certificates
  #
  # @return [Array<OpenSSL::X509::Certificate>]
  def decode_cert_bundle(bundle_str)
    re = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m
    pem_ary = bundle_str.scan(re)
    pem_ary.map do |pem_str|
      OpenSSL::X509::Certificate.new(pem_str)
    end
  end
  private :decode_cert_bundle

  # read_file makes testing easier.
  def read_file(path)
    # https://www.ietf.org/rfc/rfc2459.txt defines the x509 V3 certificate format
    # CA bundles are concatenated X509 certificates, but may also include
    # comments, which could have UTF-8 characters
    Puppet::FileSystem.read(path, :encoding => Encoding::UTF_8)
  end
  private :read_file
end
end
end
