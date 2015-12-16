# Take care of signing a certificate in a FIPS 140-2 compliant manner.
#
# @see https://projects.puppetlabs.com/issues/17295
#
# @api private
class Puppet::SSL::CertificateSigner
  def initialize
    if OpenSSL::Digest.const_defined?('SHA256')
      @digest = OpenSSL::Digest::SHA256
    elsif OpenSSL::Digest.const_defined?('SHA1')
      @digest = OpenSSL::Digest::SHA1
    else
      raise Puppet::Error,
        "No FIPS 140-2 compliant digest algorithm in OpenSSL::Digest"
    end
    @digest
  end

  def sign(content, key)
    content.sign(key, @digest.new)
  end
end
