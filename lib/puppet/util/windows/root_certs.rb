require 'puppet/util/windows'
require 'openssl'
require 'ffi'

# Represents a collection of trusted root certificates.
#
# @api public
class Puppet::Util::Windows::RootCerts
  include Enumerable
  extend FFI::Library

  def initialize(roots)
    @roots = roots
  end

  # Enumerates each root certificate.
  # @yieldparam cert [OpenSSL::X509::Certificate] each root certificate
  # @api public
  def each
    @roots.each {|cert| yield cert}
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
    # https://www.mail-archive.com/openssl-dev@openssl.org/msg26958.html
    ptr = FFI::Pointer::NULL
    store = CertOpenSystemStoreA(nil, "ROOT")
    begin
      while (ptr = CertEnumCertificatesInStore(store, ptr)) and not ptr.null?
        context = CERT_CONTEXT.new(ptr)
        cert_buf = context[:pbCertEncoded].read_bytes(context[:cbCertEncoded])
        begin
          certs << OpenSSL::X509::Certificate.new(cert_buf)
        rescue => detail
          Puppet.warning(_("Failed to import root certificate: %{detail}") % { detail: detail.inspect })
        end
      end
    ensure
      CertCloseStore(store, 0)
    end

    certs
  end

  ffi_convention :stdcall
  # typedef void *HCERTSTORE;

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa377189(v=vs.85).aspx
  # typedef struct _CERT_CONTEXT {
  #   DWORD      dwCertEncodingType;
  #   BYTE       *pbCertEncoded;
  #   DWORD      cbCertEncoded;
  #   PCERT_INFO pCertInfo;
  #   HCERTSTORE hCertStore;
  # } CERT_CONTEXT, *PCERT_CONTEXT;typedef const CERT_CONTEXT *PCCERT_CONTEXT;
  class CERT_CONTEXT < FFI::Struct
    layout(
      :dwCertEncodingType, :dword,
      :pbCertEncoded,      :pointer,
      :cbCertEncoded,      :dword,
      :pCertInfo,          :pointer,
      :hCertStore,         :handle
    )
  end

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa376560(v=vs.85).aspx
  # HCERTSTORE
  # WINAPI
  # CertOpenSystemStoreA(
  #   __in_opt HCRYPTPROV_LEGACY hProv,
  #   __in LPCSTR szSubsystemProtocol
  #   );
  # typedef ULONG_PTR HCRYPTPROV_LEGACY;
  ffi_lib :crypt32
  attach_function_private :CertOpenSystemStoreA, [:ulong_ptr, :lpcstr], :handle

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa376050(v=vs.85).aspx
  # PCCERT_CONTEXT
  # WINAPI
  # CertEnumCertificatesInStore(
  #   __in HCERTSTORE hCertStore,
  #   __in_opt PCCERT_CONTEXT pPrevCertContext
  #   );
  ffi_lib :crypt32
  attach_function_private :CertEnumCertificatesInStore, [:handle, :pointer], :pointer

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa376026(v=vs.85).aspx
  # BOOL
  # WINAPI
  # CertCloseStore(
  #   __in_opt HCERTSTORE hCertStore,
  #   __in DWORD dwFlags
  #   );
  ffi_lib :crypt32
  attach_function_private :CertCloseStore, [:handle, :dword], :win32_bool
end
