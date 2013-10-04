require 'puppet/util/windows'
require 'openssl'
require 'Win32API'
require 'windows/msvcrt/buffer'

# Represents a collection of trusted root certificates.
#
# @api public
class Puppet::Util::Windows::RootCerts
  include Enumerable

  CertOpenSystemStore         = Win32API.new('crypt32', 'CertOpenSystemStore', ['L','P'], 'L')
  CertEnumCertificatesInStore = Win32API.new('crypt32', 'CertEnumCertificatesInStore', ['L', 'L'], 'L')
  CertCloseStore              = Win32API.new('crypt32', 'CertCloseStore', ['L', 'L'], 'B')

  def initialize(roots)
    @roots = roots
  end

  # Enumerates each root certificate.
  # @yieldparam cert [OpenSSL::X509::Certificate] each root certificate
  # @api public
  def each
    @roots.each {|cert| yield cert}
  end

  class << self
    include Windows::MSVCRT::Buffer
  end

  # Returns a new instance.
  # @return [Puppet::Util::Windows::RootCerts] object constructed from current root certificates
  def self.instance
    new(self.load_certs)
  end

  # Returns an array of root certificates.
  #
  # @return [Array<[OpenSSL::X509::Certificate]>] an array of root certificates
  # @api private
  def self.load_certs
    certs = []

    # This is based on a patch submitted to openssl:
    # http://www.mail-archive.com/openssl-dev@openssl.org/msg26958.html
    context = 0
    store = CertOpenSystemStore.call(0, "ROOT")
    begin
      while (context = CertEnumCertificatesInStore.call(store, context) and context != 0)
        # 466 typedef struct _CERT_CONTEXT {
        # 467     DWORD      dwCertEncodingType;
        # 468     BYTE       *pbCertEncoded;
        # 469     DWORD      cbCertEncoded;
        # 470     PCERT_INFO pCertInfo;
        # 471     HCERTSTORE hCertStore;
        # 472 } CERT_CONTEXT, *PCERT_CONTEXT;

        # buffer to hold struct above
        ctx_buf = 0.chr * 5 * 8

        # copy from win to ruby
        memcpy(ctx_buf, context, ctx_buf.size)

        # unpack structure
        arr = ctx_buf.unpack('LLLLL')

        # create buf of length cbCertEncoded
        cert_buf = 0.chr * arr[2]

        # copy pbCertEncoded from win to ruby
        memcpy(cert_buf, arr[1], cert_buf.length)

        # create a cert
        begin
          certs << OpenSSL::X509::Certificate.new(cert_buf)
        rescue => detail
          Puppet.warning("Failed to import root certificate: #{detail.inspect}")
        end
      end
    ensure
      CertCloseStore.call(store, 0)
    end

    certs
  end
end
