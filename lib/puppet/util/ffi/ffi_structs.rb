require 'puppet/util/windows/api_types'
# require 'puppet/util/FFI'
module Puppet::Util::FFI
module FFIStructs

#   extend FFI::Library
#   extend Puppet::Util::Windows::APITypes
  
#   # extend Puppet::Util::Windows::String
  
#   # PROCESS_monkey

#  # https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/aa379560(v=vs.85)
#   # typedef struct _SECURITY_ATTRIBUTES {
#   #   DWORD  nLength;
#   #   LPVOID lpSecurityDescriptor;
#   #   BOOL   bInheritHandle;
#   # } SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;
#   class SECURITY_ATTRIBUTES < FFI::Struct
#     layout(
#       :nLength, :dword,
#       :lpSecurityDescriptor, :lpvoid,
#       :bInheritHandle, :win32_bool
#     )
#   end

#   private_constant :SECURITY_ATTRIBUTES

#   # sizeof(STARTUPINFO) == 68
#   # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfoa
#   # typedef struct _STARTUPINFOA {
#   #   DWORD  cb;
#   #   LPSTR  lpReserved;
#   #   LPSTR  lpDesktop;
#   #   LPSTR  lpTitle;
#   #   DWORD  dwX;
#   #   DWORD  dwY;
#   #   DWORD  dwXSize;
#   #   DWORD  dwYSize;
#   #   DWORD  dwXCountChars;
#   #   DWORD  dwYCountChars;
#   #   DWORD  dwFillAttribute;
#   #   DWORD  dwFlags;
#   #   WORD   wShowWindow;
#   #   WORD   cbReserved2;
#   #   LPBYTE lpReserved2;
#   #   HANDLE hStdInput;
#   #   HANDLE hStdOutput;
#   #   HANDLE hStdError;
#   # } STARTUPINFOA, *LPSTARTUPINFOA;
#   class STARTUPINFO < FFI::Struct
#     layout(
#       :cb, :dword,
#       :lpReserved, :lpcstr,
#       :lpDesktop, :lpcstr,
#       :lpTitle, :lpcstr,
#       :dwX, :dword,
#       :dwY, :dword,
#       :dwXSize, :dword,
#       :dwYSize, :dword,
#       :dwXCountChars, :dword,
#       :dwYCountChars, :dword,
#       :dwFillAttribute, :dword,
#       :dwFlags, :dword,
#       :wShowWindow, :word,
#       :cbReserved2, :word,
#       :lpReserved2, :pointer,
#       :hStdInput, :handle,
#       :hStdOutput, :handle,
#       :hStdError, :handle
#     )
#   end

#   private_constant :STARTUPINFO

#   # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-process_information
#   # typedef struct _PROCESS_INFORMATION {
#   #   HANDLE hProcess;
#   #   HANDLE hThread;
#   #   DWORD  dwProcessId;
#   #   DWORD  dwThreadId;
#   # } PROCESS_INFORMATION, *PPROCESS_INFORMATION, *LPPROCESS_INFORMATION;
#   class PROCESS_INFORMATION < FFI::Struct
#     layout(
#       :hProcess, :handle,
#       :hThread, :handle,
#       :dwProcessId, :dword,
#       :dwThreadId, :dword
#     )
#   end

#   private_constant :PROCESS_INFORMATION

#   # --------------------------

#  #PROCESS 


#   # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379261(v=vs.85).aspx
#   # typedef struct _LUID {
#   #   DWORD LowPart;
#   #   LONG  HighPart;
#   # } LUID, *PLUID;
#   class LUID < FFI::Struct
#     layout :LowPart, :dword,
#            :HighPart, :win32_long
#   end

#   # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379263(v=vs.85).aspx
#   # typedef struct _LUID_AND_ATTRIBUTES {
#   #   LUID  Luid;
#   #   DWORD Attributes;
#   # } LUID_AND_ATTRIBUTES, *PLUID_AND_ATTRIBUTES;
#   class LUID_AND_ATTRIBUTES < FFI::Struct
#     layout :Luid, LUID,
#            :Attributes, :dword
#   end

#   # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379630(v=vs.85).aspx
#   # typedef struct _TOKEN_PRIVILEGES {
#   #   DWORD               PrivilegeCount;
#   #   LUID_AND_ATTRIBUTES Privileges[ANYSIZE_ARRAY];
#   # } TOKEN_PRIVILEGES, *PTOKEN_PRIVILEGES;
#   class TOKEN_PRIVILEGES < FFI::Struct
#     layout :PrivilegeCount, :dword,
#            :Privileges, [LUID_AND_ATTRIBUTES, 1]    # placeholder for offset
#   end

#   # https://msdn.microsoft.com/en-us/library/windows/desktop/bb530717(v=vs.85).aspx
#   # typedef struct _TOKEN_ELEVATION {
#   #   DWORD TokenIsElevated;
#   # } TOKEN_ELEVATION, *PTOKEN_ELEVATION;
#   class TOKEN_ELEVATION < FFI::Struct
#     layout :TokenIsElevated, :dword
#   end

end
end