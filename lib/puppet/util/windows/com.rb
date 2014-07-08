require 'ffi'

module Puppet::Util::Windows::COM
  extend FFI::Library

  ffi_convention :stdcall

  S_OK = 0
  S_FALSE = 1

  def SUCCEEDED(hr) hr >= 0 end
  def FAILED(hr) hr < 0 end

  module_function :SUCCEEDED, :FAILED

  def raise_if_hresult_failed(name, *args)
    failed = FAILED(result = send(name, *args)) and raise "#{name} failed (hresult #{format('%#08x', result)})."

    result
  ensure
    yield failed if block_given?
  end

  module_function :raise_if_hresult_failed

  CLSCTX_INPROC_SERVER = 0x1
  CLSCTX_INPROC_HANDLER = 0x2
  CLSCTX_LOCAL_SERVER = 0x4
  CLSCTX_INPROC_SERVER16 = 0x8
  CLSCTX_REMOTE_SERVER = 0x10
  CLSCTX_INPROC_HANDLER16 = 0x20
  CLSCTX_RESERVED1 = 0x40
  CLSCTX_RESERVED2 = 0x80
  CLSCTX_RESERVED3 = 0x100
  CLSCTX_RESERVED4 = 0x200
  CLSCTX_NO_CODE_DOWNLOAD = 0x400
  CLSCTX_RESERVED5 = 0x800
  CLSCTX_NO_CUSTOM_MARSHAL = 0x1000
  CLSCTX_ENABLE_CODE_DOWNLOAD = 0x2000
  CLSCTX_NO_FAILURE_LOG = 0x4000
  CLSCTX_DISABLE_AAA = 0x8000
  CLSCTX_ENABLE_AAA = 0x10000
  CLSCTX_FROM_DEFAULT_CONTEXT = 0x20000
  CLSCTX_ACTIVATE_32_BIT_SERVER = 0x40000
  CLSCTX_ACTIVATE_64_BIT_SERVER = 0x80000
  CLSCTX_ENABLE_CLOAKING = 0x100000
  CLSCTX_PS_DLL = -0x80000000
  CLSCTX_INPROC = CLSCTX_INPROC_SERVER | CLSCTX_INPROC_HANDLER
  CLSCTX_ALL = CLSCTX_INPROC_SERVER | CLSCTX_INPROC_HANDLER | CLSCTX_LOCAL_SERVER | CLSCTX_REMOTE_SERVER
  CLSCTX_SERVER = CLSCTX_INPROC_SERVER | CLSCTX_LOCAL_SERVER | CLSCTX_REMOTE_SERVER

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms686615(v=vs.85).aspx
  # HRESULT CoCreateInstance(
  #   _In_   REFCLSID rclsid,
  #   _In_   LPUNKNOWN pUnkOuter,
  #   _In_   DWORD dwClsContext,
  #   _In_   REFIID riid,
  #   _Out_  LPVOID *ppv
  # );
  ffi_lib :ole32
  attach_function_private :CoCreateInstance,
    [:pointer, :lpunknown, :dword, :pointer, :lpvoid], :hresult

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms678543(v=vs.85).aspx
  # HRESULT CoInitialize(
  #   _In_opt_  LPVOID pvReserved
  # );
  ffi_lib :ole32
  attach_function_private :CoInitialize, [:lpvoid], :hresult

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms688715(v=vs.85).aspx
  # void CoUninitialize(void);
  ffi_lib :ole32
  attach_function :CoUninitialize, [], :void

  def InitializeCom
    raise_if_hresult_failed(:CoInitialize, FFI::Pointer::NULL)

    at_exit { CoUninitialize() }
  end

  module_function :InitializeCom

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms680722(v=vs.85).aspx
  # void CoTaskMemFree(
  #   _In_opt_  LPVOID pv
  # );
  ffi_lib :ole32
  attach_function :CoTaskMemFree, [:lpvoid], :void
end
