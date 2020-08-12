# require 'puppet/util/ffi/structs'
# require 'puppet/util/ffi/constants'
# require 'puppet/util/ffi'
# require 'ffi'

module Puppet::Util::FFI
module FFIFunctions

  # require 'ffi'
  # extend FFI::Library
  # include FFIConstants

  # # PROCESS_monkey

  # ffi_convention :stdcall

  # # https://docs.microsoft.com/en-us/windows/win32/api/handleapi/nf-handleapi-sethandleinformation
  # # BOOL SetHandleInformation(
  # #   HANDLE hObject,
  # #   DWORD  dwMask,
  # #   DWORD  dwFlags
  # # );
  # ffi_lib :kernel32
  # attach_function_private :SetHandleInformation, [:handle, :dword, :dword], :win32_bool

  # # https://docs.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-seterrormode
  # # UINT SetErrorMode(
  # #   UINT uMode
  # # );
  # ffi_lib :kernel32
  # attach_function_private :SetErrorMode, [:uint], :uint

  # # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw
  # # BOOL CreateProcessW(
  # #   LPCWSTR               lpApplicationName,
  # #   LPWSTR                lpCommandLine,
  # #   LPSECURITY_ATTRIBUTES lpProcessAttributes,
  # #   LPSECURITY_ATTRIBUTES lpThreadAttributes,
  # #   BOOL                  bInheritHandles,
  # #   DWORD                 dwCreationFlags,
  # #   LPVOID                lpEnvironment,
  # #   LPCWSTR               lpCurrentDirectory,
  # #   LPSTARTUPINFOW        lpStartupInfo,
  # #   LPPROCESS_INFORMATION lpProcessInformation
  # # );
  # ffi_lib :kernel32
  # attach_function_private :CreateProcessW,
  #   [:lpcwstr, :lpwstr, :pointer, :pointer, :win32_bool,
  #    :dword, :lpvoid, :lpcwstr, :pointer, :pointer], :bool

  # # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocess
  # # HANDLE OpenProcess(
  # #   DWORD dwDesiredAccess,
  # #   BOOL  bInheritHandle,
  # #   DWORD dwProcessId
  # # );
  # ffi_lib :kernel32
  # attach_function_private :OpenProcess, [:dword, :win32_bool, :dword], :handle

  # # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setpriorityclass
  # # BOOL SetPriorityClass(
  # #   HANDLE hProcess,
  # #   DWORD  dwPriorityClass
  # # );
  # ffi_lib :kernel32
  # attach_function_private :SetPriorityClass, [:handle, :dword], :win32_bool

  # # https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createprocesswithlogonw
  # # BOOL CreateProcessWithLogonW(
  # #   LPCWSTR               lpUsername,
  # #   LPCWSTR               lpDomain,
  # #   LPCWSTR               lpPassword,
  # #   DWORD                 dwLogonFlags,
  # #   LPCWSTR               lpApplicationName,
  # #   LPWSTR                lpCommandLine,
  # #   DWORD                 dwCreationFlags,
  # #   LPVOID                lpEnvironment,
  # #   LPCWSTR               lpCurrentDirectory,
  # #   LPSTARTUPINFOW        lpStartupInfo,
  # #   LPPROCESS_INFORMATION lpProcessInformation
  # # );
  # ffi_lib :advapi32
  # attach_function_private :CreateProcessWithLogonW,
  #   [:lpcwstr, :lpcwstr, :lpcwstr, :dword, :lpcwstr, :lpwstr,
  #    :dword, :lpvoid, :lpcwstr, :pointer, :pointer], :bool

  # # https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/get-osfhandle?view=vs-2019
  # # intptr_t _get_osfhandle(
  # #    int fd
  # # );
  # ffi_lib FFI::Library::LIBC
  # attach_function_private :get_osfhandle, :_get_osfhandle, [:int], :intptr_t

  # begin
  #   # https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/get-errno?view=vs-2019
  #   # errno_t _get_errno(
  #   #    int * pValue
  #   # );
  #   attach_function_private :get_errno, :_get_errno, [:pointer], :int
  # rescue FFI::NotFoundError
  #   # Do nothing, Windows XP or earlier.
  # end


  # # --------------------------

  # #PROCESS


  # ffi_convention :stdcall

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/ms687032(v=vs.85).aspx
  # # DWORD WINAPI WaitForSingleObject(
  # #   _In_  HANDLE hHandle,
  # #   _In_  DWORD dwMilliseconds
  # # );
  # ffi_lib :kernel32
  # attach_function_private :WaitForSingleObject,
  #   [:handle, :dword], :dword

  # # https://docs.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitformultipleobjects
  # #   DWORD WaitForMultipleObjects(
  # #   DWORD        nCount,
  # #   const HANDLE *lpHandles,
  # #   BOOL         bWaitAll,
  # #   DWORD        dwMilliseconds
  # # );
  # ffi_lib :kernel32
  # attach_function_private :WaitForMultipleObjects,
  #   [:dword, :phandle, :win32_bool, :dword], :dword

  # # https://docs.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-createeventw
  # # HANDLE CreateEventW(
  # #   LPSECURITY_ATTRIBUTES lpEventAttributes,
  # #   BOOL                  bManualReset,
  # #   BOOL                  bInitialState,
  # #   LPCWSTR               lpName
  # # );
  # ffi_lib :kernel32
  # attach_function_private :CreateEventW,
  #   [:pointer, :win32_bool, :win32_bool, :lpcwstr], :handle

  # # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createthread
  # # HANDLE CreateThread(
  # #   LPSECURITY_ATTRIBUTES   lpThreadAttributes,
  # #   SIZE_T                  dwStackSize,
  # #   LPTHREAD_START_ROUTINE  lpStartAddress,
  # #   __drv_aliasesMem LPVOID lpParameter,
  # #   DWORD                   dwCreationFlags,
  # #   LPDWORD                 lpThreadId
  # # );
  # ffi_lib :kernel32
  # attach_function_private :CreateThread,
  #   [:pointer, :size_t, :pointer, :lpvoid, :dword, :lpdword], :handle, :blocking => true

  # # https://docs.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-setevent
  # # BOOL SetEvent(
  # #   HANDLE hEvent
  # # );
  # ffi_lib :kernel32
  # attach_function_private :SetEvent,
  #   [:handle], :win32_bool

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/ms683189(v=vs.85).aspx
  # # BOOL WINAPI GetExitCodeProcess(
  # #   _In_   HANDLE hProcess,
  # #   _Out_  LPDWORD lpExitCode
  # # );
  # ffi_lib :kernel32
  # attach_function_private :GetExitCodeProcess,
  #   [:handle, :lpdword], :win32_bool

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/ms683179(v=vs.85).aspx
  # # HANDLE WINAPI GetCurrentProcess(void);
  # ffi_lib :kernel32
  # attach_function_private :GetCurrentProcess, [], :handle

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/ms683187(v=vs.85).aspx
  # # LPTCH GetEnvironmentStrings(void);
  # ffi_lib :kernel32
  # attach_function_private :GetEnvironmentStringsW, [], :pointer

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/ms683151(v=vs.85).aspx
  # # BOOL FreeEnvironmentStrings(
  # #   _In_ LPTCH lpszEnvironmentBlock
  # # );
  # ffi_lib :kernel32
  # attach_function_private :FreeEnvironmentStringsW,
  #   [:pointer], :win32_bool

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/ms686206(v=vs.85).aspx
  # # BOOL WINAPI SetEnvironmentVariableW(
  # #     _In_     LPCTSTR lpName,
  # #     _In_opt_ LPCTSTR lpValue
  # #   );
  # ffi_lib :kernel32
  # attach_function_private :SetEnvironmentVariableW,
  #   [:lpcwstr, :lpcwstr], :win32_bool

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/ms684320(v=vs.85).aspx
  # # HANDLE WINAPI OpenProcess(
  # #   _In_   DWORD DesiredAccess,
  # #   _In_   BOOL InheritHandle,
  # #   _In_   DWORD ProcessId
  # # );
  # ffi_lib :kernel32
  # attach_function_private :OpenProcess,
  #   [:dword, :win32_bool, :dword], :handle

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379295(v=vs.85).aspx
  # # BOOL WINAPI OpenProcessToken(
  # #   _In_   HANDLE ProcessHandle,
  # #   _In_   DWORD DesiredAccess,
  # #   _Out_  PHANDLE TokenHandle
  # # );
  # ffi_lib :advapi32
  # attach_function_private :OpenProcessToken,
  #   [:handle, :dword, :phandle], :win32_bool

  # # https://docs.microsoft.com/en-us/windows/desktop/api/winbase/nf-winbase-queryfullprocessimagenamew
  # # BOOL WINAPI QueryFullProcessImageName(
  # #   _In_   HANDLE hProcess,
  # #   _In_   DWORD dwFlags,
  # #   _Out_  LPWSTR lpExeName,
  # #   _In_   PDWORD lpdwSize,
  # # );
  # ffi_lib :kernel32
  # attach_function_private :QueryFullProcessImageNameW,
  #   [:handle, :dword, :lpwstr, :pdword], :win32_bool


  # # https://msdn.microsoft.com/en-us/library/Windows/desktop/aa379180(v=vs.85).aspx
  # # BOOL WINAPI LookupPrivilegeValue(
  # #   _In_opt_  LPCTSTR lpSystemName,
  # #   _In_      LPCTSTR lpName,
  # #   _Out_     PLUID lpLuid
  # # );
  # ffi_lib :advapi32
  # attach_function_private :LookupPrivilegeValueW,
  #   [:lpcwstr, :lpcwstr, :pointer], :win32_bool

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446671(v=vs.85).aspx
  # # BOOL WINAPI GetTokenInformation(
  # #   _In_       HANDLE TokenHandle,
  # #   _In_       TOKEN_INFORMATION_CLASS TokenInformationClass,
  # #   _Out_opt_  LPVOID TokenInformation,
  # #   _In_       DWORD TokenInformationLength,
  # #   _Out_      PDWORD ReturnLength
  # # );
  # ffi_lib :advapi32
  # attach_function_private :GetTokenInformation,
  #   [:handle, TOKEN_INFORMATION_CLASS, :lpvoid, :dword, :pdword ], :win32_bool

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724451(v=vs.85).aspx
  # # BOOL WINAPI GetVersionEx(
  # #   _Inout_  LPOSVERSIONINFO lpVersionInfo
  # # );
  # ffi_lib :kernel32
  # attach_function_private :GetVersionExW,
  #   [:pointer], :win32_bool

  # # https://msdn.microsoft.com/en-us/library/windows/desktop/dd318123(v=vs.85).aspx
  # # LANGID GetSystemDefaultUILanguage(void);
  # ffi_lib :kernel32
  # attach_function_private :GetSystemDefaultUILanguage, [], :word
end
end