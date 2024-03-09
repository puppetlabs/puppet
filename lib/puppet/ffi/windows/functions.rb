# frozen_string_literal: true

require_relative '../../../puppet/ffi/windows'

module Puppet::FFI::Windows
  module Functions
    extend FFI::Library
    include Puppet::FFI::Windows::Constants

    ffi_convention :stdcall

    # https://docs.microsoft.com/en-us/windows/win32/api/handleapi/nf-handleapi-sethandleinformation
    # BOOL SetHandleInformation(
    #   HANDLE hObject,
    #   DWORD  dwMask,
    #   DWORD  dwFlags
    # );
    ffi_lib :kernel32
    attach_function_private :SetHandleInformation, [:handle, :dword, :dword], :win32_bool

    # https://docs.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-seterrormode
    # UINT SetErrorMode(
    #   UINT uMode
    # );
    ffi_lib :kernel32
    attach_function_private :SetErrorMode, [:uint], :uint

    # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw
    # BOOL CreateProcessW(
    #   LPCWSTR               lpApplicationName,
    #   LPWSTR                lpCommandLine,
    #   LPSECURITY_ATTRIBUTES lpProcessAttributes,
    #   LPSECURITY_ATTRIBUTES lpThreadAttributes,
    #   BOOL                  bInheritHandles,
    #   DWORD                 dwCreationFlags,
    #   LPVOID                lpEnvironment,
    #   LPCWSTR               lpCurrentDirectory,
    #   LPSTARTUPINFOW        lpStartupInfo,
    #   LPPROCESS_INFORMATION lpProcessInformation
    # );
    ffi_lib :kernel32
    attach_function_private :CreateProcessW,
                            [:lpcwstr, :lpwstr, :pointer, :pointer, :win32_bool,
                             :dword, :lpvoid, :lpcwstr, :pointer, :pointer], :bool

    # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocess
    # HANDLE OpenProcess(
    #   DWORD dwDesiredAccess,
    #   BOOL  bInheritHandle,
    #   DWORD dwProcessId
    # );
    ffi_lib :kernel32
    attach_function_private :OpenProcess, [:dword, :win32_bool, :dword], :handle

    # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setpriorityclass
    # BOOL SetPriorityClass(
    #   HANDLE hProcess,
    #   DWORD  dwPriorityClass
    # );
    ffi_lib :kernel32
    attach_function_private :SetPriorityClass, [:handle, :dword], :win32_bool

    # https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createprocesswithlogonw
    # BOOL CreateProcessWithLogonW(
    #   LPCWSTR               lpUsername,
    #   LPCWSTR               lpDomain,
    #   LPCWSTR               lpPassword,
    #   DWORD                 dwLogonFlags,
    #   LPCWSTR               lpApplicationName,
    #   LPWSTR                lpCommandLine,
    #   DWORD                 dwCreationFlags,
    #   LPVOID                lpEnvironment,
    #   LPCWSTR               lpCurrentDirectory,
    #   LPSTARTUPINFOW        lpStartupInfo,
    #   LPPROCESS_INFORMATION lpProcessInformation
    # );
    ffi_lib :advapi32
    attach_function_private :CreateProcessWithLogonW,
                            [:lpcwstr, :lpcwstr, :lpcwstr, :dword, :lpcwstr, :lpwstr,
                             :dword, :lpvoid, :lpcwstr, :pointer, :pointer], :bool

    # https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/get-osfhandle?view=vs-2019
    # intptr_t _get_osfhandle(
    #    int fd
    # );
    ffi_lib FFI::Library::LIBC
    attach_function_private :get_osfhandle, :_get_osfhandle, [:int], :intptr_t

    begin
      # https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/get-errno?view=vs-2019
      # errno_t _get_errno(
      #    int * pValue
      # );
      attach_function_private :get_errno, :_get_errno, [:pointer], :int
    rescue FFI::NotFoundError
      # Do nothing, Windows XP or earlier.
    end

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms687032(v=vs.85).aspx
    # DWORD WINAPI WaitForSingleObject(
    #   _In_  HANDLE hHandle,
    #   _In_  DWORD dwMilliseconds
    # );
    ffi_lib :kernel32
    attach_function_private :WaitForSingleObject,
                            [:handle, :dword], :dword, :blocking => true

    # https://docs.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitformultipleobjects
    #   DWORD WaitForMultipleObjects(
    #   DWORD        nCount,
    #   const HANDLE *lpHandles,
    #   BOOL         bWaitAll,
    #   DWORD        dwMilliseconds
    # );
    ffi_lib :kernel32
    attach_function_private :WaitForMultipleObjects,
                            [:dword, :phandle, :win32_bool, :dword], :dword

    # https://docs.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-createeventw
    # HANDLE CreateEventW(
    #   LPSECURITY_ATTRIBUTES lpEventAttributes,
    #   BOOL                  bManualReset,
    #   BOOL                  bInitialState,
    #   LPCWSTR               lpName
    # );
    ffi_lib :kernel32
    attach_function_private :CreateEventW,
                            [:pointer, :win32_bool, :win32_bool, :lpcwstr], :handle

    # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createthread
    # HANDLE CreateThread(
    #   LPSECURITY_ATTRIBUTES   lpThreadAttributes,
    #   SIZE_T                  dwStackSize,
    #   LPTHREAD_START_ROUTINE  lpStartAddress,
    #   __drv_aliasesMem LPVOID lpParameter,
    #   DWORD                   dwCreationFlags,
    #   LPDWORD                 lpThreadId
    # );
    ffi_lib :kernel32
    attach_function_private :CreateThread,
                            [:pointer, :size_t, :pointer, :lpvoid, :dword, :lpdword], :handle, :blocking => true

    # https://docs.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-setevent
    # BOOL SetEvent(
    #   HANDLE hEvent
    # );
    ffi_lib :kernel32
    attach_function_private :SetEvent,
                            [:handle], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms683189(v=vs.85).aspx
    # BOOL WINAPI GetExitCodeProcess(
    #   _In_   HANDLE hProcess,
    #   _Out_  LPDWORD lpExitCode
    # );
    ffi_lib :kernel32
    attach_function_private :GetExitCodeProcess,
                            [:handle, :lpdword], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms683179(v=vs.85).aspx
    # HANDLE WINAPI GetCurrentProcess(void);
    ffi_lib :kernel32
    attach_function_private :GetCurrentProcess, [], :handle

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms683187(v=vs.85).aspx
    # LPTCH GetEnvironmentStrings(void);
    ffi_lib :kernel32
    attach_function_private :GetEnvironmentStringsW, [], :pointer

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms683151(v=vs.85).aspx
    # BOOL FreeEnvironmentStrings(
    #   _In_ LPTCH lpszEnvironmentBlock
    # );
    ffi_lib :kernel32
    attach_function_private :FreeEnvironmentStringsW,
                            [:pointer], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms686206(v=vs.85).aspx
    # BOOL WINAPI SetEnvironmentVariableW(
    #     _In_     LPCTSTR lpName,
    #     _In_opt_ LPCTSTR lpValue
    #   );
    ffi_lib :kernel32
    attach_function_private :SetEnvironmentVariableW,
                            [:lpcwstr, :lpcwstr], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms684320(v=vs.85).aspx
    # HANDLE WINAPI OpenProcess(
    #   _In_   DWORD DesiredAccess,
    #   _In_   BOOL InheritHandle,
    #   _In_   DWORD ProcessId
    # );
    ffi_lib :kernel32
    attach_function_private :OpenProcess,
                            [:dword, :win32_bool, :dword], :handle

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379295(v=vs.85).aspx
    # BOOL WINAPI OpenProcessToken(
    #   _In_   HANDLE ProcessHandle,
    #   _In_   DWORD DesiredAccess,
    #   _Out_  PHANDLE TokenHandle
    # );
    ffi_lib :advapi32
    attach_function_private :OpenProcessToken,
                            [:handle, :dword, :phandle], :win32_bool

    # https://docs.microsoft.com/en-us/windows/desktop/api/winbase/nf-winbase-queryfullprocessimagenamew
    # BOOL WINAPI QueryFullProcessImageName(
    #   _In_   HANDLE hProcess,
    #   _In_   DWORD dwFlags,
    #   _Out_  LPWSTR lpExeName,
    #   _In_   PDWORD lpdwSize,
    # );
    ffi_lib :kernel32
    attach_function_private :QueryFullProcessImageNameW,
                            [:handle, :dword, :lpwstr, :pdword], :win32_bool

    # https://msdn.microsoft.com/en-us/library/Windows/desktop/aa379180(v=vs.85).aspx
    # BOOL WINAPI LookupPrivilegeValue(
    #   _In_opt_  LPCTSTR lpSystemName,
    #   _In_      LPCTSTR lpName,
    #   _Out_     PLUID lpLuid
    # );
    ffi_lib :advapi32
    attach_function_private :LookupPrivilegeValueW,
                            [:lpcwstr, :lpcwstr, :pointer], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446671(v=vs.85).aspx
    # BOOL WINAPI GetTokenInformation(
    #   _In_       HANDLE TokenHandle,
    #   _In_       TOKEN_INFORMATION_CLASS TokenInformationClass,
    #   _Out_opt_  LPVOID TokenInformation,
    #   _In_       DWORD TokenInformationLength,
    #   _Out_      PDWORD ReturnLength
    # );
    ffi_lib :advapi32
    attach_function_private :GetTokenInformation,
                            [:handle, TOKEN_INFORMATION_CLASS, :lpvoid, :dword, :pdword], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724451(v=vs.85).aspx
    # BOOL WINAPI GetVersionEx(
    #   _Inout_  LPOSVERSIONINFO lpVersionInfo
    # );
    ffi_lib :kernel32
    attach_function_private :GetVersionExW,
                            [:pointer], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/dd318123(v=vs.85).aspx
    # LANGID GetSystemDefaultUILanguage(void);
    ffi_lib :kernel32
    attach_function_private :GetSystemDefaultUILanguage, [], :word

    # https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-openscmanagerw
    # SC_HANDLE OpenSCManagerW(
    #   LPCWSTR lpMachineName,
    #   LPCWSTR lpDatabaseName,
    #   DWORD   dwDesiredAccess
    # );
    ffi_lib :advapi32
    attach_function_private :OpenSCManagerW,
                            [:lpcwstr, :lpcwstr, :dword], :handle

    # https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-openservicew
    # SC_HANDLE OpenServiceW(
    #   SC_HANDLE hSCManager,
    #   LPCWSTR   lpServiceName,
    #   DWORD     dwDesiredAccess
    # );
    ffi_lib :advapi32
    attach_function_private :OpenServiceW,
                            [:handle, :lpcwstr, :dword], :handle

    # https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-closeservicehandle
    # BOOL CloseServiceHandle(
    #   SC_HANDLE hSCObject
    # );
    ffi_lib :advapi32
    attach_function_private :CloseServiceHandle,
                            [:handle], :win32_bool

    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/nf-winsvc-queryservicestatusex
    # BOOL QueryServiceStatusEx(
    #   SC_HANDLE      hService,
    #   SC_STATUS_TYPE InfoLevel,
    #   LPBYTE         lpBuffer,
    #   DWORD          cbBufSize,
    #   LPDWORD        pcbBytesNeeded
    # );
    SC_STATUS_TYPE = enum(
      :SC_STATUS_PROCESS_INFO, 0
    )
    ffi_lib :advapi32
    attach_function_private :QueryServiceStatusEx,
                            [:handle, SC_STATUS_TYPE, :lpbyte, :dword, :lpdword], :win32_bool

    # https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-queryserviceconfigw
    # BOOL QueryServiceConfigW(
    #   SC_HANDLE               hService,
    #   LPQUERY_SERVICE_CONFIGW lpServiceConfig,
    #   DWORD                   cbBufSize,
    #   LPDWORD                 pcbBytesNeeded
    # );
    ffi_lib :advapi32
    attach_function_private :QueryServiceConfigW,
                            [:handle, :lpbyte, :dword, :lpdword], :win32_bool

    # https://docs.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-queryserviceconfig2w
    # BOOL QueryServiceConfig2W(
    #   SC_HANDLE hService,
    #   DWORD     dwInfoLevel,
    #   LPBYTE    lpBuffer,
    #   DWORD     cbBufSize,
    #   LPDWORD   pcbBytesNeeded
    # );
    ffi_lib :advapi32
    attach_function_private :QueryServiceConfig2W,
                            [:handle, :dword, :lpbyte, :dword, :lpdword], :win32_bool

    # https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-startservicew
    # BOOL StartServiceW(
    #   SC_HANDLE hService,
    #   DWORD     dwNumServiceArgs,
    #   LPCWSTR   *lpServiceArgVectors
    # );
    ffi_lib :advapi32
    attach_function_private :StartServiceW,
                            [:handle, :dword, :pointer], :win32_bool

    # https://docs.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-startservicectrldispatcherw
    # BOOL StartServiceCtrlDispatcherW(
    #   const SERVICE_TABLE_ENTRYW *lpServiceStartTable
    # );
    ffi_lib :advapi32
    attach_function_private :StartServiceCtrlDispatcherW,
                            [:pointer], :win32_bool, :blocking => true

    # https://docs.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-setservicestatus
    # BOOL SetServiceStatus(
    #   SERVICE_STATUS_HANDLE hServiceStatus,
    #   LPSERVICE_STATUS      lpServiceStatus
    # );
    ffi_lib :advapi32
    attach_function_private :SetServiceStatus,
                            [:handle, :pointer], :win32_bool

    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/nf-winsvc-controlservice
    # BOOL ControlService(
    #   SC_HANDLE        hService,
    #   DWORD            dwControl,
    #   LPSERVICE_STATUS lpServiceStatus
    # );
    ffi_lib :advapi32
    attach_function_private :ControlService,
                            [:handle, :dword, :pointer], :win32_bool

    #   DWORD LphandlerFunctionEx(
    #   DWORD dwControl,
    #   DWORD dwEventType,
    #   LPVOID lpEventData,
    #   LPVOID lpContext
    # )
    callback :handler_ex, [:dword, :dword, :lpvoid, :lpvoid], :void

    # https://docs.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-registerservicectrlhandlerexw
    # SERVICE_STATUS_HANDLE RegisterServiceCtrlHandlerExW(
    #   LPCWSTR               lpServiceName,
    #   LPHANDLER_FUNCTION_EX lpHandlerProc,
    #   LPVOID                lpContext
    # );
    ffi_lib :advapi32
    attach_function_private :RegisterServiceCtrlHandlerExW,
                            [:lpcwstr, :handler_ex, :lpvoid], :handle

    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/nf-winsvc-changeserviceconfigw
    # BOOL ChangeServiceConfigW(
    #   SC_HANDLE hService,
    #   DWORD     dwServiceType,
    #   DWORD     dwStartType,
    #   DWORD     dwErrorControl,
    #   LPCWSTR   lpBinaryPathName,
    #   LPCWSTR   lpLoadOrderGroup,
    #   LPDWORD   lpdwTagId,
    #   LPCWSTR   lpDependencies,
    #   LPCWSTR   lpServiceStartName,
    #   LPCWSTR   lpPassword,
    #   LPCWSTR   lpDisplayName
    # );
    ffi_lib :advapi32
    attach_function_private :ChangeServiceConfigW,
                            [
                              :handle,
                              :dword,
                              :dword,
                              :dword,
                              :lpcwstr,
                              :lpcwstr,
                              :lpdword,
                              :lpcwstr,
                              :lpcwstr,
                              :lpcwstr,
                              :lpcwstr
                            ], :win32_bool

    # https://docs.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-changeserviceconfig2w
    # BOOL ChangeServiceConfig2W(
    #   SC_HANDLE hService,
    #   DWORD     dwInfoLevel,
    #   LPVOID    lpInfo
    # );
    ffi_lib :advapi32
    attach_function_private :ChangeServiceConfig2W,
                            [:handle, :dword, :lpvoid], :win32_bool

    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/nf-winsvc-enumservicesstatusexw
    # BOOL EnumServicesStatusExW(
    #   SC_HANDLE    hSCManager,
    #   SC_ENUM_TYPE InfoLevel,
    #   DWORD        dwServiceType,
    #   DWORD        dwServiceState,
    #   LPBYTE       lpServices,
    #   DWORD        cbBufSize,
    #   LPDWORD      pcbBytesNeeded,
    #   LPDWORD      lpServicesReturned,
    #   LPDWORD      lpResumeHandle,
    #   LPCWSTR      pszGroupName
    # );
    SC_ENUM_TYPE = enum(
      :SC_ENUM_PROCESS_INFO, 0
    )
    ffi_lib :advapi32
    attach_function_private :EnumServicesStatusExW,
                            [
                              :handle,
                              SC_ENUM_TYPE,
                              :dword,
                              :dword,
                              :lpbyte,
                              :dword,
                              :lpdword,
                              :lpdword,
                              :lpdword,
                              :lpcwstr
                            ], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa365512(v=vs.85).aspx
    # BOOL WINAPI ReplaceFile(
    #   _In_        LPCTSTR lpReplacedFileName,
    #   _In_        LPCTSTR lpReplacementFileName,
    #   _In_opt_    LPCTSTR lpBackupFileName,
    #   _In_        DWORD dwReplaceFlags - 0x1 REPLACEFILE_WRITE_THROUGH,
    #                                      0x2 REPLACEFILE_IGNORE_MERGE_ERRORS,
    #                                      0x4 REPLACEFILE_IGNORE_ACL_ERRORS
    #   _Reserved_  LPVOID lpExclude,
    #   _Reserved_  LPVOID lpReserved
    # );
    ffi_lib :kernel32
    attach_function_private :ReplaceFileW,
                            [:lpcwstr, :lpcwstr, :lpcwstr, :dword, :lpvoid, :lpvoid], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa365240(v=vs.85).aspx
    # BOOL WINAPI MoveFileEx(
    #   _In_      LPCTSTR lpExistingFileName,
    #   _In_opt_  LPCTSTR lpNewFileName,
    #   _In_      DWORD dwFlags
    # );
    ffi_lib :kernel32
    attach_function_private :MoveFileExW,
                            [:lpcwstr, :lpcwstr, :dword], :win32_bool

    # BOOLEAN WINAPI CreateSymbolicLink(
    #   _In_  LPTSTR lpSymlinkFileName, - symbolic link to be created
    #   _In_  LPTSTR lpTargetFileName, - name of target for symbolic link
    #   _In_  DWORD dwFlags - 0x0 target is a file, 0x1 target is a directory
    # );
    # rescue on Windows < 6.0 so that code doesn't explode
    begin
      ffi_lib :kernel32
      attach_function_private :CreateSymbolicLinkW,
                              [:lpwstr, :lpwstr, :dword], :boolean
    rescue LoadError
    end

    # https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getcurrentdirectory
    # DWORD GetCurrentDirectory(
    #   DWORD  nBufferLength,
    #   LPTSTR lpBuffer
    # );
    ffi_lib :kernel32
    attach_function_private :GetCurrentDirectoryW,
                            [:dword, :lpwstr], :dword

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa364944(v=vs.85).aspx
    # DWORD WINAPI GetFileAttributes(
    #   _In_  LPCTSTR lpFileName
    # );
    ffi_lib :kernel32
    attach_function_private :GetFileAttributesW,
                            [:lpcwstr], :dword

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa365535(v=vs.85).aspx
    # BOOL WINAPI SetFileAttributes(
    #   _In_  LPCTSTR lpFileName,
    #   _In_  DWORD dwFileAttributes
    # );
    ffi_lib :kernel32
    attach_function_private :SetFileAttributesW,
                            [:lpcwstr, :dword], :win32_bool

    # HANDLE WINAPI CreateFile(
    #   _In_      LPCTSTR lpFileName,
    #   _In_      DWORD dwDesiredAccess,
    #   _In_      DWORD dwShareMode,
    #   _In_opt_  LPSECURITY_ATTRIBUTES lpSecurityAttributes,
    #   _In_      DWORD dwCreationDisposition,
    #   _In_      DWORD dwFlagsAndAttributes,
    #   _In_opt_  HANDLE hTemplateFile
    # );
    ffi_lib :kernel32
    attach_function_private :CreateFileW,
                            [:lpcwstr, :dword, :dword, :pointer, :dword, :dword, :handle], :handle

    # https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createdirectoryw
    # BOOL CreateDirectoryW(
    #   LPCWSTR               lpPathName,
    #   LPSECURITY_ATTRIBUTES lpSecurityAttributes
    # );
    ffi_lib :kernel32
    attach_function_private :CreateDirectoryW,
                            [:lpcwstr, :pointer], :win32_bool

    # https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-removedirectoryw
    # BOOL RemoveDirectoryW(
    #   LPCWSTR lpPathName
    # );
    ffi_lib :kernel32
    attach_function_private :RemoveDirectoryW,
                            [:lpcwstr], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363216(v=vs.85).aspx
    # BOOL WINAPI DeviceIoControl(
    #   _In_         HANDLE hDevice,
    #   _In_         DWORD dwIoControlCode,
    #   _In_opt_     LPVOID lpInBuffer,
    #   _In_         DWORD nInBufferSize,
    #   _Out_opt_    LPVOID lpOutBuffer,
    #   _In_         DWORD nOutBufferSize,
    #   _Out_opt_    LPDWORD lpBytesReturned,
    #   _Inout_opt_  LPOVERLAPPED lpOverlapped
    # );
    ffi_lib :kernel32
    attach_function_private :DeviceIoControl,
                            [:handle, :dword, :lpvoid, :dword, :lpvoid, :dword, :lpdword, :pointer], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa364980(v=vs.85).aspx
    # DWORD WINAPI GetLongPathName(
    #   _In_  LPCTSTR lpszShortPath,
    #   _Out_ LPTSTR  lpszLongPath,
    #   _In_  DWORD   cchBuffer
    # );
    ffi_lib :kernel32
    attach_function_private :GetLongPathNameW,
                            [:lpcwstr, :lpwstr, :dword], :dword

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa364989(v=vs.85).aspx
    # DWORD WINAPI GetShortPathName(
    #   _In_  LPCTSTR lpszLongPath,
    #   _Out_ LPTSTR  lpszShortPath,
    #   _In_  DWORD   cchBuffer
    # );
    ffi_lib :kernel32
    attach_function_private :GetShortPathNameW,
                            [:lpcwstr, :lpwstr, :dword], :dword

    # https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfullpathnamew
    # DWORD GetFullPathNameW(
    #   LPCWSTR lpFileName,
    #   DWORD   nBufferLength,
    #   LPWSTR  lpBuffer,
    #   LPWSTR  *lpFilePart
    # );
    ffi_lib :kernel32
    attach_function_private :GetFullPathNameW,
                            [:lpcwstr, :dword, :lpwstr, :pointer], :dword

    # https://docs.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shgetfolderpathw
    # SHFOLDERAPI SHGetFolderPathW(
    #   HWND   hwnd,
    #   int    csidl,
    #   HANDLE hToken,
    #   DWORD  dwFlags,
    #   LPWSTR pszPath
    # );
    ffi_lib :shell32
    attach_function_private :SHGetFolderPathW,
                            [:hwnd, :int, :handle, :dword, :lpwstr], :dword

    # https://docs.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shgetfolderlocation
    # SHSTDAPI SHGetFolderLocation(
    #   HWND             hwnd,
    #   int              csidl,
    #   HANDLE           hToken,
    #   DWORD            dwFlags,
    #   PIDLIST_ABSOLUTE *ppidl
    # );
    ffi_lib :shell32
    attach_function_private :SHGetFolderLocation,
                            [:hwnd, :int, :handle, :dword, :pointer], :dword

    # https://docs.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-shgetfileinfoa
    # DWORD_PTR SHGetFileInfoA(
    #   LPCSTR      pszPath,
    #   DWORD       dwFileAttributes,
    #   SHFILEINFOA *psfi,
    #   UINT        cbFileInfo,
    #   UINT        uFlags
    # );
    ffi_lib :shell32
    attach_function_private :SHGetFileInfo,
                            [:dword, :dword, :pointer, :uint, :uint], :dword

    # https://docs.microsoft.com/en-us/windows/win32/api/shlwapi/nf-shlwapi-pathisdirectoryemptyw
    # BOOL PathIsDirectoryEmptyW(
    #   LPCWSTR pszPath
    # );
    ffi_lib :shlwapi
    attach_function_private :PathIsDirectoryEmptyW,
                            [:lpcwstr], :win32_bool
  end
end
