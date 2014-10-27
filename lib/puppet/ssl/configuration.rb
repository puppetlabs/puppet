require 'puppet/ssl'
require 'openssl'
module Puppet
module SSL
  # Puppet::SSL::Configuration is intended to separate out the following concerns:
  # * CA certificates that authenticate peers (ca_auth_file)
  # * Who clients trust as distinct from who servers trust.  We should not
  #   assume one single self signed CA cert for everyone.
class Configuration
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
    File.read(path)
  end
  private :read_file
end
end
end
