require 'puppet/util/windows'
require 'ffi'

module Puppet::Util::Windows
  # This module is designed to provide an API between the windows system and puppet for
  # service management.
  #
  # for an overview of the service state transitions see: https://docs.microsoft.com/en-us/windows/desktop/Services/service-status-transitions
  module Service
    extend FFI::Library
    extend Puppet::Util::Windows::String

    FILE = Puppet::Util::Windows::File

    # integer value of the floor for timeouts when waiting for service pending states.
    # puppet will wait the length of dwWaitHint if it is longer than this value, but
    # no shorter
    DEFAULT_TIMEOUT = 30

    # Service control codes
    # https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-controlserviceexw
    SERVICE_CONTROL_STOP                  = 0x00000001
    SERVICE_CONTROL_PAUSE                 = 0x00000002
    SERVICE_CONTROL_CONTINUE              = 0x00000003
    SERVICE_CONTROL_INTERROGATE           = 0x00000004
    SERVICE_CONTROL_SHUTDOWN              = 0x00000005
    SERVICE_CONTROL_PARAMCHANGE           = 0x00000006
    SERVICE_CONTROL_NETBINDADD            = 0x00000007
    SERVICE_CONTROL_NETBINDREMOVE         = 0x00000008
    SERVICE_CONTROL_NETBINDENABLE         = 0x00000009
    SERVICE_CONTROL_NETBINDDISABLE        = 0x0000000A
    SERVICE_CONTROL_DEVICEEVENT           = 0x0000000B
    SERVICE_CONTROL_HARDWAREPROFILECHANGE = 0x0000000C
    SERVICE_CONTROL_POWEREVENT            = 0x0000000D
    SERVICE_CONTROL_SESSIONCHANGE         = 0x0000000E
    SERVICE_CONTROL_PRESHUTDOWN           = 0x0000000F
    SERVICE_CONTROL_TIMECHANGE            = 0x00000010
    SERVICE_CONTROL_TRIGGEREVENT          = 0x00000020

    # Service start type codes
    # https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-changeserviceconfigw
    SERVICE_AUTO_START = 0x00000002
    SERVICE_BOOT_START = 0x00000000
    SERVICE_DEMAND_START = 0x00000003
    SERVICE_DISABLED = 0x00000004
    SERVICE_SYSTEM_START = 0x00000001
    SERVICE_START_TYPES = {
      SERVICE_AUTO_START => :SERVICE_AUTO_START,
      SERVICE_BOOT_START => :SERVICE_BOOT_START,
      SERVICE_DEMAND_START => :SERVICE_DEMAND_START,
      SERVICE_DISABLED => :SERVICE_DISABLED,
      SERVICE_SYSTEM_START => :SERVICE_SYSTEM_START,
    }

    # Service type codes
    # https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-changeserviceconfigw
    SERVICE_FILE_SYSTEM_DRIVER  = 0x00000002
    SERVICE_KERNEL_DRIVER       = 0x00000001
    SERVICE_WIN32_OWN_PROCESS   = 0x00000010
    SERVICE_WIN32_SHARE_PROCESS = 0x00000020
    SERVICE_USER_OWN_PROCESS    = 0x00000050
    SERVICE_USER_SHARE_PROCESS  = 0x00000060
    # Available only if service is also SERVICE_WIN32_OWN_PROCESS or SERVICE_WIN32_SHARE_PROCESS
    SERVICE_INTERACTIVE_PROCESS = 0x00000100
    ALL_SERVICE_TYPES =
      SERVICE_FILE_SYSTEM_DRIVER |
      SERVICE_KERNEL_DRIVER |
      SERVICE_WIN32_OWN_PROCESS |
      SERVICE_WIN32_SHARE_PROCESS

    # Current state codes
    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/ns-winsvc-_service_status_process
    SERVICE_CONTINUE_PENDING = 0x00000005
    SERVICE_PAUSE_PENDING    = 0x00000006
    SERVICE_PAUSED           = 0x00000007
    SERVICE_RUNNING          = 0x00000004
    SERVICE_START_PENDING    = 0x00000002
    SERVICE_STOP_PENDING     = 0x00000003
    SERVICE_STOPPED          = 0x00000001
    SERVICE_STATES = {
      SERVICE_CONTINUE_PENDING => :SERVICE_CONTINUE_PENDING,
      SERVICE_PAUSE_PENDING => :SERVICE_PAUSE_PENDING,
      SERVICE_PAUSED => :SERVICE_PAUSED,
      SERVICE_RUNNING => :SERVICE_RUNNING,
      SERVICE_START_PENDING => :SERVICE_START_PENDING,
      SERVICE_STOP_PENDING => :SERVICE_STOP_PENDING,
      SERVICE_STOPPED => :SERVICE_STOPPED,
    }

    # Service accepts control codes
    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/ns-winsvc-_service_status_process
    SERVICE_ACCEPT_STOP                  = 0x00000001
    SERVICE_ACCEPT_PAUSE_CONTINUE        = 0x00000002
    SERVICE_ACCEPT_SHUTDOWN              = 0x00000004
    SERVICE_ACCEPT_PARAMCHANGE           = 0x00000008
    SERVICE_ACCEPT_NETBINDCHANGE         = 0x00000010
    SERVICE_ACCEPT_HARDWAREPROFILECHANGE = 0x00000020
    SERVICE_ACCEPT_POWEREVENT            = 0x00000040
    SERVICE_ACCEPT_SESSIONCHANGE         = 0x00000080
    SERVICE_ACCEPT_PRESHUTDOWN           = 0x00000100
    SERVICE_ACCEPT_TIMECHANGE            = 0x00000200
    SERVICE_ACCEPT_TRIGGEREVENT          = 0x00000400
    SERVICE_ACCEPT_USER_LOGOFF           = 0x00000800

    # Service manager access codes
    # https://docs.microsoft.com/en-us/windows/desktop/Services/service-security-and-access-rights
    SC_MANAGER_CREATE_SERVICE     = 0x00000002
    SC_MANAGER_CONNECT            = 0x00000001
    SC_MANAGER_ENUMERATE_SERVICE  = 0x00000004
    SC_MANAGER_LOCK               = 0x00000008
    SC_MANAGER_MODIFY_BOOT_CONFIG = 0x00000020
    SC_MANAGER_QUERY_LOCK_STATUS  = 0x00000010
    SC_MANAGER_ALL_ACCESS         =
      FILE::STANDARD_RIGHTS_REQUIRED |
      SC_MANAGER_CREATE_SERVICE      |
      SC_MANAGER_CONNECT             |
      SC_MANAGER_ENUMERATE_SERVICE   |
      SC_MANAGER_LOCK                |
      SC_MANAGER_MODIFY_BOOT_CONFIG  |
      SC_MANAGER_QUERY_LOCK_STATUS


    # Service access codes
    # https://docs.microsoft.com/en-us/windows/desktop/Services/service-security-and-access-rights
    SERVICE_CHANGE_CONFIG        = 0x0002
    SERVICE_ENUMERATE_DEPENDENTS = 0x0008
    SERVICE_INTERROGATE          = 0x0080
    SERVICE_PAUSE_CONTINUE       = 0x0040
    SERVICE_QUERY_STATUS         = 0x0004
    SERVICE_QUERY_CONFIG         = 0x0001
    SERVICE_START                = 0x0010
    SERVICE_STOP                 = 0x0020
    SERVICE_USER_DEFINED_CONTROL = 0x0100
    SERVICE_ALL_ACCESS           =
      FILE::STANDARD_RIGHTS_REQUIRED |
      SERVICE_CHANGE_CONFIG          |
      SERVICE_ENUMERATE_DEPENDENTS   |
      SERVICE_INTERROGATE            |
      SERVICE_PAUSE_CONTINUE         |
      SERVICE_QUERY_STATUS           |
      SERVICE_QUERY_CONFIG           |
      SERVICE_START                  |
      SERVICE_STOP                   |
      SERVICE_USER_DEFINED_CONTROL

    # Service config codes
    # From the windows 10 SDK:
    # //
    # // Value to indicate no change to an optional parameter
    # //
    # #define SERVICE_NO_CHANGE              0xffffffff
    SERVICE_NO_CHANGE = 0xffffffff

    # Service enum codes
    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/nf-winsvc-enumservicesstatusexa
    SERVICE_ACTIVE = 0x00000001
    SERVICE_INACTIVE = 0x00000002
    SERVICE_STATE_ALL =
      SERVICE_ACTIVE |
      SERVICE_INACTIVE

    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/ns-winsvc-_enum_service_status_processw
    SERVICENAME_MAX = 256

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

    # Start a windows service, assume that the service is already in the stopped state
    #
    # @param [:string] service_name name of the service to start
    def start(service_name)
      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_START | SERVICE_QUERY_STATUS) do |service|
        # don't attempt to fail here if the service isn't stopped because windows error codes
        # are likely more informative than ours and a failed call to StartServiceW will produce
        # those errors
        wait_for_pending_transition(service, SERVICE_STOP_PENDING, SERVICE_STOPPED)
        if StartServiceW(service, 0, FFI::Pointer::NULL) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(_("Failed to start the service"))
        end
        unless wait_for_pending_transition(service, SERVICE_START_PENDING, SERVICE_RUNNING)
          raise Puppet::Error.new(_("Failed to start the service, after calling StartService the service is not in SERVICE_START_PENDING or SERVICE_RUNNING"))
        end
      end
    end
    module_function :start

    # Use ControlService to send a stop signal to a windows service
    #
    # @param [:string] service_name name of the service to stop
    def stop(service_name)
      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_STOP | SERVICE_QUERY_STATUS) do |service|
        FFI::MemoryPointer.new(SERVICE_STATUS.size) do |status_ptr|
          status = SERVICE_STATUS.new(status_ptr)
          # don't attempt to fail here if the service isn't started because windows error codes
          # are likely more informative than ours and a failed call to ControlService will produce
          # those errors
          wait_for_pending_transition(service, SERVICE_START_PENDING, SERVICE_RUNNING)
          if ControlService(service, SERVICE_CONTROL_STOP, status) == FFI::WIN32_FALSE
            raise Puppet::Util::Windows::Error.new(_("Failed to send stop control to service, current state is %{current_state}. Failed with") % { current_state: status[:dwCurrentState].to_s })
          end
          unless wait_for_pending_transition(service, SERVICE_STOP_PENDING, SERVICE_STOPPED)
            raise Puppet::Error.new(_("Failed to stop the service, after calling ControlService the service is not in SERVICE_STOP_PENDING or SERVICE_STOPPED"))
          end
        end
      end
    end
    module_function :stop

    # Query the state of a service using QueryServiceStatusEx
    #
    # @param [:string] service_name name of the service to query
    # @return [string] the status of the service
    def service_state(service_name)
      status = nil
      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_QUERY_STATUS) do |service|
        status = query_status(service)
      end
      state = SERVICE_STATES[status[:dwCurrentState]]
      if state.nil?
        raise Puppet::Error.new(_("Unknown Service state '%{current_state}' for '%{service_name}'") % { current_state: status[:dwCurrentState].to_s, service_name: service_name})
      end
      state
    end
    module_function :service_state

    # Query the configuration of a service using QueryServiceConfigW
    #
    # @param [:string] service_name name of the service to query
    # @return [QUERY_SERVICE_CONFIGW.struct] the configuration of the service
    def service_start_type(service_name)
      config = nil
      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_QUERY_CONFIG) do |service|
        config = query_config(service)
      end
      start_type = SERVICE_START_TYPES[config[:dwStartType]]
      if start_type.nil?
        raise Puppet::Error.new(_("Unknown start type '%{start_type}' for '%{service_name}'") % { start_type: config[:dwStartType].to_s, service_name: service_name})
      end
      start_type
    end
    module_function :service_start_type

    # Change the startup mode of a windows service
    #
    # @param [string] service_name the name of the service to modify
    # @param [Int] startup_type a code corresponding to a start type for
    #  windows service, see the "Service start type codes" section in the
    #  Puppet::Util::Windows::Service file for the list of available codes
    def set_startup_mode(service_name, startup_type)
      startup_code = SERVICE_START_TYPES.key(startup_type)
      if startup_code.nil?
        raise Puppet::Error.new(_("Unknown start type %{start_type}") % {startup_type: startup_type.to_s})
      end
      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_CHANGE_CONFIG) do |service|
        # Currently the only thing puppet's API can really manage
        # in this list is dwStartType (the third param). Thus no
        # generic function was written to make use of all the params
        # since the API as-is couldn't use them anyway
        success = ChangeServiceConfigW(
          service,
          SERVICE_NO_CHANGE,  # dwServiceType
          startup_code,       # dwStartType
          SERVICE_NO_CHANGE,  # dwErrorControl
          FFI::Pointer::NULL, # lpBinaryPathName
          FFI::Pointer::NULL, # lpLoadOrderGroup
          FFI::Pointer::NULL, # lpdwTagId
          FFI::Pointer::NULL, # lpDependencies
          FFI::Pointer::NULL, # lpServiceStartName
          FFI::Pointer::NULL, # lpPassword
          FFI::Pointer::NULL  # lpDisplayName
        )
        if success == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(_("Failed to update service configuration"))
        end
      end
    end
    module_function :set_startup_mode

    # enumerate over all services in all states and return them as a hash
    #
    # @return [Hash] a hash containing services:
    #   { 'service name' => {
    #                         'display_name' => 'display name',
    #                         'service_status_process' => SERVICE_STATUS_PROCESS struct
    #                       }
    #   }
    def services
      services = {}
      open_scm(SC_MANAGER_ENUMERATE_SERVICE) do |scm|
        size_required = 0
        services_returned = 0
        FFI::MemoryPointer.new(:dword) do |bytes_pointer|
          FFI::MemoryPointer.new(:dword) do |svcs_ret_ptr|
            FFI::MemoryPointer.new(:dword) do |resume_ptr|
              resume_ptr.write_dword(0)
              # Fetch the bytes of memory required to be allocated
              # for QueryServiceConfigW to return succesfully. This
              # is done by sending NULL and 0 for the pointer and size
              # respectively, letting the command fail, then reading the
              # value of pcbBytesNeeded
              #
              # return value will be false from this call, since it's designed
              # to fail. Just ignore it
              EnumServicesStatusExW(
                scm,
                :SC_ENUM_PROCESS_INFO,
                ALL_SERVICE_TYPES,
                SERVICE_STATE_ALL,
                FFI::Pointer::NULL,
                0,
                bytes_pointer,
                svcs_ret_ptr,
                resume_ptr,
                FFI::Pointer::NULL
              )
              size_required = bytes_pointer.read_dword
              FFI::MemoryPointer.new(size_required) do |buffer_ptr|
                resume_ptr.write_dword(0)
                svcs_ret_ptr.write_dword(0)
                success = EnumServicesStatusExW(
                  scm,
                  :SC_ENUM_PROCESS_INFO,
                  ALL_SERVICE_TYPES,
                  SERVICE_STATE_ALL,
                  buffer_ptr,
                  buffer_ptr.size,
                  bytes_pointer,
                  svcs_ret_ptr,
                  resume_ptr,
                  FFI::Pointer::NULL
                )
                if success == FFI::WIN32_FALSE
                  raise Puppet::Util::Windows::Error.new(_("Failed to fetch services"))
                end
                # Now that the buffer is populated with services
                # we pull the data from memory using pointer arithmetic:
                # the number of services returned by the function is
                # available to be read from svcs_ret_ptr, and we iterate
                # that many times moving the cursor pointer the length of
                # ENUM_SERVICE_STATUS_PROCESSW.size. This should iterate
                # over the buffer and extract each struct.
                services_returned = svcs_ret_ptr.read_dword
                cursor_ptr = FFI::Pointer.new(ENUM_SERVICE_STATUS_PROCESSW, buffer_ptr)
                0.upto(services_returned - 1) do |index|
                  service = ENUM_SERVICE_STATUS_PROCESSW.new(cursor_ptr[index])
                  services[service[:lpServiceName].read_arbitrary_wide_string_up_to(SERVICENAME_MAX)] = {
                    :display_name => service[:lpDisplayName].read_arbitrary_wide_string_up_to(SERVICENAME_MAX),
                    :service_status_process => service[:ServiceStatusProcess]
                  }
                end
              end # buffer_ptr
            end # resume_ptr
          end # scvs_ret_ptr
        end # bytes_ptr
      end # open_scm
      services
    end
    module_function :services

    class << self
      # @api private
      # Opens a connection to the SCManager on windows then uses that
      # handle to create a handle to a specific service in windows
      # corresponding to service_name
      #
      # this function takes a block that executes within the context of
      # the open service handler, and will close the service and SCManager
      # handles once the block finishes
      #
      # @param [string] service_name the name of the service to open
      # @param [Integer] scm_access code corresponding to the access type requested for the scm
      # @param [Integer] service_access code corresponding to the access type requested for the service
      # @yieldparam [:handle] service the windows native handle used to access
      #   the service
      def open_service(service_name, scm_access, service_access, &block)
        service = FFI::Pointer::NULL_HANDLE
        open_scm(scm_access) do |scm|
          service = OpenServiceW(scm, wide_string(service_name), service_access)
          raise Puppet::Util::Windows::Error.new(_("Failed to open a handle to the service")) if service == FFI::Pointer::NULL_HANDLE
          yield service
        end
      ensure
        CloseServiceHandle(service)
      end
      private :open_service

      # @api private
      #
      # Opens a handle to the service control manager
      #
      # @param [Integer] scm_access code corresponding to the access type requested for the scm
      def open_scm(scm_access, &block)
        scm = OpenSCManagerW(FFI::Pointer::NULL, FFI::Pointer::NULL, scm_access)
        raise Puppet::Util::Windows::Error.new(_("Failed to open a handle to the service control manager")) if scm == FFI::Pointer::NULL_HANDLE
        yield scm
      ensure
        CloseServiceHandle(scm)
      end
      private :open_scm

      # @api private
      # perform QueryServiceStatusEx on a windows service and return the
      # result
      #
      # @param [:handle] service handle of the service to query
      # @return [SERVICE_STATUS_PROCESS struct] the result of the query
      def query_status(service)
        size_required = nil
        status = nil
        # Fetch the bytes of memory required to be allocated
        # for QueryServiceConfigW to return succesfully. This
        # is done by sending NULL and 0 for the pointer and size
        # respectively, letting the command fail, then reading the
        # value of pcbBytesNeeded
        FFI::MemoryPointer.new(:lpword) do |bytes_pointer|
          # return value will be false from this call, since it's designed
          # to fail. Just ignore it
          QueryServiceStatusEx(
            service,
            :SC_STATUS_PROCESS_INFO,
            FFI::Pointer::NULL,
            0,
            bytes_pointer
          )
          size_required = bytes_pointer.read_dword
          FFI::MemoryPointer.new(size_required) do |ssp_ptr|
            status = SERVICE_STATUS_PROCESS.new(ssp_ptr)
            success = QueryServiceStatusEx(
              service,
              :SC_STATUS_PROCESS_INFO,
              ssp_ptr,
              size_required,
              bytes_pointer
            )
            if success == FFI::WIN32_FALSE
              raise Puppet::Util::Windows::Error.new(_("Service query failed"))
            end
          end
        end
        status
      end
      private :query_status

      # @api private
      # perform QueryServiceConfigW on a windows service and return the
      # result
      #
      # @param [:handle] service handle of the service to query
      # @return [QUERY_SERVICE_CONFIGW struct] the result of the query
      def query_config(service)
        config = nil
        size_required = nil
        # Fetch the bytes of memory required to be allocated
        # for QueryServiceConfigW to return succesfully. This
        # is done by sending NULL and 0 for the pointer and size
        # respectively, letting the command fail, then reading the
        # value of pcbBytesNeeded
        FFI::MemoryPointer.new(:lpword) do |bytes_pointer|
          # return value will be false from this call, since it's designed
          # to fail. Just ignore it
          QueryServiceConfigW(service, FFI::Pointer::NULL, 0, bytes_pointer)
          size_required = bytes_pointer.read_dword
          FFI::MemoryPointer.new(size_required) do |ssp_ptr|
            config = QUERY_SERVICE_CONFIGW.new(ssp_ptr)
            success = QueryServiceConfigW(
              service,
              ssp_ptr,
              size_required,
              bytes_pointer
            )
            if success == FFI::WIN32_FALSE
              raise Puppet::Util::Windows::Error.new(_("Service query failed"))
            end
          end
        end
        config
      end
      private :query_config

      # @api private
      # waits for a windows service to report final_state if it
      # is in pending_state
      #
      # @param [:handle] service handle to the service to wait on
      # @param [Integer] pending_state the state to wait on
      # @param [Integer] final_state the state indicating the transition is finished
      # @return [bool] 'true' once the service is reporting final_state,
      #   'false' if the service was not in pending_state or finaL_state
      def wait_for_pending_transition(service, pending_state, final_state)
        elapsed_time = 0
        last_checkpoint = -1
        loop do
          status = query_status(service)
          state = status[:dwCurrentState]
          return true if state == final_state
          unless state == pending_state
            return false
          end
          # When the service is in the pending state we need to do the following:
          # 1. check if any progress has been made since dwWaitHint using dwCheckPoint,
          #    and fail if no progress was made
          # 2. if progress has been made, increment elapsed_time and set last_checkpoint
          # 3. sleep, then loop again if there was progress.
          time_to_wait = wait_hint_to_wait_time(status[:dwWaitHint])
          if status[:dwCheckPoint] > last_checkpoint
            elapsed_time = 0
          else
            timeout = milliseconds_to_seconds(status[:dwWaitHint]);
            timeout = DEFAULT_TIMEOUT if timeout < DEFAULT_TIMEOUT
            if elapsed_time >= (timeout)
              raise Puppet::Error.new(_("No progress made on service operation and dwWaitHint exceeded"))
            end
          end
          last_checkpoint = status[:dwCheckPoint]
          sleep(time_to_wait)
          elapsed_time += time_to_wait
        end
      end
      private :wait_for_pending_transition

      # @api private
      #
      # create a usable wait time to wait between querying the service.
      #
      # @param [Integer] wait_hint the wait hint of a service in milliseconds
      # @return [Integer] the time to wait in seconds between querying the service
      def wait_hint_to_wait_time(wait_hint)
        # Wait 1/10th the wait_hint, but no less than 1 and
        # no more than 10 seconds
        wait_time = milliseconds_to_seconds(wait_hint) / 10;
        wait_time = 1 if wait_time < 1
        wait_time = 10 if wait_time > 10
        wait_time
      end
      private :wait_hint_to_wait_time

      # @api private
      #
      # process the wait hint listed by a service to something
      # usable by ruby sleep
      #
      # @param [Integer] wait_hint the wait hint of a service in milliseconds
      # @return [Integer] wait_hint in seconds
      def milliseconds_to_seconds(wait_hint)
        wait_hint / 1000;
      end
      private :milliseconds_to_seconds
    end

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
      :SC_STATUS_PROCESS_INFO, 0,
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

    # https://docs.microsoft.com/en-us/windows/desktop/api/Winsvc/nf-winsvc-startservicew
    # BOOL StartServiceW(
    #   SC_HANDLE hService,
    #   DWORD     dwNumServiceArgs,
    #   LPCWSTR   *lpServiceArgVectors
    # );
    ffi_lib :advapi32
    attach_function_private :StartServiceW,
      [:handle, :dword, :pointer], :win32_bool

    # https://docs.microsoft.com/en-us/windows/desktop/api/winsvc/nf-winsvc-controlservice
    # BOOL ControlService(
    #   SC_HANDLE        hService,
    #   DWORD            dwControl,
    #   LPSERVICE_STATUS lpServiceStatus
    # );
    ffi_lib :advapi32
    attach_function_private :ControlService,
      [:handle, :dword, :pointer], :win32_bool

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
      :SC_ENUM_PROCESS_INFO, 0,
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
  end
end
