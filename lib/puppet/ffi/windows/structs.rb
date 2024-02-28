# coding: utf-8
# frozen_string_literal: true

require_relative '../../../puppet/ffi/windows'

module Puppet::FFI::Windows
  module Structs
    extend FFI::Library
    extend Puppet::FFI::Windows::APITypes

    # https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/aa379560(v=vs.85)
    # typedef struct _SECURITY_ATTRIBUTES {
    #   DWORD  nLength;
    #   LPVOID lpSecurityDescriptor;
    #   BOOL   bInheritHandle;
    # } SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;
    class SECURITY_ATTRIBUTES < FFI::Struct
      layout(
        :nLength, :dword,
        :lpSecurityDescriptor, :lpvoid,
        :bInheritHandle, :win32_bool
      )
    end

    private_constant :SECURITY_ATTRIBUTES

    # sizeof(STARTUPINFO) == 68
    # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfoa
    # typedef struct _STARTUPINFOA {
    #   DWORD  cb;
    #   LPSTR  lpReserved;
    #   LPSTR  lpDesktop;
    #   LPSTR  lpTitle;
    #   DWORD  dwX;
    #   DWORD  dwY;
    #   DWORD  dwXSize;
    #   DWORD  dwYSize;
    #   DWORD  dwXCountChars;
    #   DWORD  dwYCountChars;
    #   DWORD  dwFillAttribute;
    #   DWORD  dwFlags;
    #   WORD   wShowWindow;
    #   WORD   cbReserved2;
    #   LPBYTE lpReserved2;
    #   HANDLE hStdInput;
    #   HANDLE hStdOutput;
    #   HANDLE hStdError;
    # } STARTUPINFOA, *LPSTARTUPINFOA;
    class STARTUPINFO < FFI::Struct
      layout(
        :cb, :dword,
        :lpReserved, :lpcstr,
        :lpDesktop, :lpcstr,
        :lpTitle, :lpcstr,
        :dwX, :dword,
        :dwY, :dword,
        :dwXSize, :dword,
        :dwYSize, :dword,
        :dwXCountChars, :dword,
        :dwYCountChars, :dword,
        :dwFillAttribute, :dword,
        :dwFlags, :dword,
        :wShowWindow, :word,
        :cbReserved2, :word,
        :lpReserved2, :pointer,
        :hStdInput, :handle,
        :hStdOutput, :handle,
        :hStdError, :handle
      )
    end

    private_constant :STARTUPINFO

    # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-process_information
    # typedef struct _PROCESS_INFORMATION {
    #   HANDLE hProcess;
    #   HANDLE hThread;
    #   DWORD  dwProcessId;
    #   DWORD  dwThreadId;
    # } PROCESS_INFORMATION, *PPROCESS_INFORMATION, *LPPROCESS_INFORMATION;
    class PROCESS_INFORMATION < FFI::Struct
      layout(
        :hProcess, :handle,
        :hThread, :handle,
        :dwProcessId, :dword,
        :dwThreadId, :dword
      )
    end

    private_constant :PROCESS_INFORMATION

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379261(v=vs.85).aspx
    # typedef struct _LUID {
    #   DWORD LowPart;
    #   LONG  HighPart;
    # } LUID, *PLUID;
    class LUID < FFI::Struct
      layout :LowPart, :dword,
             :HighPart, :win32_long
    end

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379263(v=vs.85).aspx
    # typedef struct _LUID_AND_ATTRIBUTES {
    #   LUID  Luid;
    #   DWORD Attributes;
    # } LUID_AND_ATTRIBUTES, *PLUID_AND_ATTRIBUTES;
    class LUID_AND_ATTRIBUTES < FFI::Struct
      layout :Luid, LUID,
             :Attributes, :dword
    end

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379630(v=vs.85).aspx
    # typedef struct _TOKEN_PRIVILEGES {
    #   DWORD               PrivilegeCount;
    #   LUID_AND_ATTRIBUTES Privileges[ANYSIZE_ARRAY];
    # } TOKEN_PRIVILEGES, *PTOKEN_PRIVILEGES;
    class TOKEN_PRIVILEGES < FFI::Struct
      layout :PrivilegeCount, :dword,
             :Privileges, [LUID_AND_ATTRIBUTES, 1] # placeholder for offset
    end

    # https://msdn.microsoft.com/en-us/library/windows/desktop/bb530717(v=vs.85).aspx
    # typedef struct _TOKEN_ELEVATION {
    #   DWORD TokenIsElevated;
    # } TOKEN_ELEVATION, *PTOKEN_ELEVATION;
    class TOKEN_ELEVATION < FFI::Struct
      layout :TokenIsElevated, :dword
    end

    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/ns-winsvc-_service_status_process
    # typedef struct _SERVICE_STATUS_PROCESS {
    #   DWORD dwServiceType;
    #   DWORD dwCurrentState;
    #   DWORD dwControlsAccepted;
    #   DWORD dwWin32ExitCode;
    #   DWORD dwServiceSpecificExitCode;
    #   DWORD dwCheckPoint;
    #   DWORD dwWaitHint;
    #   DWORD dwProcessId;
    #   DWORD dwServiceFlags;
    # } SERVICE_STATUS_PROCESS, *LPSERVICE_STATUS_PROCESS;
    class SERVICE_STATUS_PROCESS < FFI::Struct
      layout(
        :dwServiceType, :dword,
        :dwCurrentState, :dword,
        :dwControlsAccepted, :dword,
        :dwWin32ExitCode, :dword,
        :dwServiceSpecificExitCode, :dword,
        :dwCheckPoint, :dword,
        :dwWaitHint, :dword,
        :dwProcessId, :dword,
        :dwServiceFlags, :dword
      )
    end

    # https://docs.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_delayed_auto_start_info
    # typedef struct _SERVICE_DELAYED_AUTO_START_INFO {
    #   BOOL fDelayedAutostart;
    # } SERVICE_DELAYED_AUTO_START_INFO, *LPSERVICE_DELAYED_AUTO_START_INFO;
    class SERVICE_DELAYED_AUTO_START_INFO < FFI::Struct
      layout(:fDelayedAutostart, :int)
      alias aset []=
      # Intercept the accessor so that we can handle either true/false or 1/0.
      # Since there is only one member, there’s no need to check the key name.
      def []=(key, value)
        [0, false].include?(value) ? aset(key, 0) : aset(key, 1)
      end
    end

    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/ns-winsvc-_enum_service_status_processw
    # typedef struct _ENUM_SERVICE_STATUS_PROCESSW {
    #   LPWSTR                 lpServiceName;
    #   LPWSTR                 lpDisplayName;
    #   SERVICE_STATUS_PROCESS ServiceStatusProcess;
    # } ENUM_SERVICE_STATUS_PROCESSW, *LPENUM_SERVICE_STATUS_PROCESSW;
    class ENUM_SERVICE_STATUS_PROCESSW < FFI::Struct
      layout(
        :lpServiceName, :pointer,
        :lpDisplayName, :pointer,
        :ServiceStatusProcess, SERVICE_STATUS_PROCESS
      )
    end

    # typedef struct _SERVICE_STATUS {
    #   DWORD dwServiceType;
    #   DWORD dwCurrentState;
    #   DWORD dwControlsAccepted;
    #   DWORD dwWin32ExitCode;
    #   DWORD dwServiceSpecificExitCode;
    #   DWORD dwCheckPoint;
    #   DWORD dwWaitHint;
    # } SERVICE_STATUS, *LPSERVICE_STATUS;
    class SERVICE_STATUS < FFI::Struct
      layout(
        :dwServiceType, :dword,
        :dwCurrentState, :dword,
        :dwControlsAccepted, :dword,
        :dwWin32ExitCode, :dword,
        :dwServiceSpecificExitCode, :dword,
        :dwCheckPoint, :dword,
        :dwWaitHint, :dword,
      )
    end

    # typedef struct _QUERY_SERVICE_CONFIGW {
    #   DWORD  dwServiceType;
    #   DWORD  dwStartType;
    #   DWORD  dwErrorControl;
    #   LPWSTR lpBinaryPathName;
    #   LPWSTR lpLoadOrderGroup;
    #   DWORD  dwTagId;
    #   LPWSTR lpDependencies;
    #   LPWSTR lpServiceStartName;
    #   LPWSTR lpDisplayName;
    # } QUERY_SERVICE_CONFIGW, *LPQUERY_SERVICE_CONFIGW;
    class QUERY_SERVICE_CONFIGW < FFI::Struct
      layout(
        :dwServiceType, :dword,
        :dwStartType, :dword,
        :dwErrorControl, :dword,
        :lpBinaryPathName, :pointer,
        :lpLoadOrderGroup, :pointer,
        :dwTagId, :dword,
        :lpDependencies, :pointer,
        :lpServiceStartName, :pointer,
        :lpDisplayName, :pointer,
      )
    end

    # typedef struct _SERVICE_TABLE_ENTRYW {
    #   LPWSTR                   lpServiceName;
    #   LPSERVICE_MAIN_FUNCTIONW lpServiceProc;
    # } SERVICE_TABLE_ENTRYW, *LPSERVICE_TABLE_ENTRYW;
    class SERVICE_TABLE_ENTRYW < FFI::Struct
      layout(
        :lpServiceName, :pointer,
        :lpServiceProc, :pointer
      )
    end

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724834%28v=vs.85%29.aspx
    # typedef struct _OSVERSIONINFO {
    #   DWORD dwOSVersionInfoSize;
    #   DWORD dwMajorVersion;
    #   DWORD dwMinorVersion;
    #   DWORD dwBuildNumber;
    #   DWORD dwPlatformId;
    #   TCHAR szCSDVersion[128];
    # } OSVERSIONINFO;
    class OSVERSIONINFO < FFI::Struct
      layout(
        :dwOSVersionInfoSize, :dword,
        :dwMajorVersion, :dword,
        :dwMinorVersion, :dword,
        :dwBuildNumber, :dword,
        :dwPlatformId, :dword,
        :szCSDVersion, [:wchar, 128]
      )
    end

    MAXIMUM_REPARSE_DATA_BUFFER_SIZE = 16_384

    # SYMLINK_REPARSE_DATA_BUFFER
    # https://msdn.microsoft.com/en-us/library/cc232006.aspx
    # https://msdn.microsoft.com/en-us/library/windows/hardware/ff552012(v=vs.85).aspx
    # struct is always MAXIMUM_REPARSE_DATA_BUFFER_SIZE bytes
    class SYMLINK_REPARSE_DATA_BUFFER < FFI::Struct
      layout :ReparseTag, :win32_ulong,
             :ReparseDataLength, :ushort,
             :Reserved, :ushort,
             :SubstituteNameOffset, :ushort,
             :SubstituteNameLength, :ushort,
             :PrintNameOffset, :ushort,
             :PrintNameLength, :ushort,
             :Flags, :win32_ulong,
             # max less above fields dword / uint 4 bytes, ushort 2 bytes
             # technically a WCHAR buffer, but we care about size in bytes here
             :PathBuffer, [:byte, MAXIMUM_REPARSE_DATA_BUFFER_SIZE - 20]
    end

    # MOUNT_POINT_REPARSE_DATA_BUFFER
    # https://msdn.microsoft.com/en-us/library/cc232007.aspx
    # https://msdn.microsoft.com/en-us/library/windows/hardware/ff552012(v=vs.85).aspx
    # struct is always MAXIMUM_REPARSE_DATA_BUFFER_SIZE bytes
    class MOUNT_POINT_REPARSE_DATA_BUFFER < FFI::Struct
      layout :ReparseTag, :win32_ulong,
             :ReparseDataLength, :ushort,
             :Reserved, :ushort,
             :SubstituteNameOffset, :ushort,
             :SubstituteNameLength, :ushort,
             :PrintNameOffset, :ushort,
             :PrintNameLength, :ushort,
             # max less above fields dword / uint 4 bytes, ushort 2 bytes
             # technically a WCHAR buffer, but we care about size in bytes here
             :PathBuffer, [:byte, MAXIMUM_REPARSE_DATA_BUFFER_SIZE - 16]
    end

    # SHFILEINFO
    # https://docs.microsoft.com/en-us/windows/win32/api/shellapi/ns-shellapi-shfileinfow
    # typedef struct _SHFILEINFOW {
    #   HICON hIcon;
    #   int   iIcon;
    #   DWORD dwAttributes;
    #   WCHAR szDisplayName[MAX_PATH];
    #   WCHAR szTypeName[80];
    # } SHFILEINFOW;
    class SHFILEINFO < FFI::Struct
      layout(
        :hIcon, :ulong,
        :iIcon, :int,
        :dwAttributes, :ulong,
        :szDisplayName, [:char, 256],
        :szTypeName, [:char, 80]
      )
    end

    # REPARSE_JDATA_BUFFER
    class REPARSE_JDATA_BUFFER < FFI::Struct
      layout(
        :ReparseTag, :ulong,
        :ReparseDataLength, :ushort,
        :Reserved, :ushort,
        :SubstituteNameOffset, :ushort,
        :SubstituteNameLength, :ushort,
        :PrintNameOffset, :ushort,
        :PrintNameLength, :ushort,
        :PathBuffer, [:char, 1024]
      )

      # The REPARSE_DATA_BUFFER_HEADER_SIZE which is calculated as:
      #
      # sizeof(ReparseTag) + sizeof(ReparseDataLength) + sizeof(Reserved)
      #
      def header_size
        FFI::Type::ULONG.size + FFI::Type::USHORT.size + FFI::Type::USHORT.size
      end
    end
  end
end
