# coding: utf-8
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

    # Service error codes
    # https://docs.microsoft.com/en-us/windows/desktop/debug/system-error-codes--1000-1299-
    ERROR_SERVICE_DOES_NOT_EXIST = 0x00000424

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
    SERVICE_CONTROL_SIGNALS               = {
      SERVICE_CONTROL_STOP                  => :SERVICE_CONTROL_STOP,
      SERVICE_CONTROL_PAUSE                 => :SERVICE_CONTROL_PAUSE,
      SERVICE_CONTROL_CONTINUE              => :SERVICE_CONTROL_CONTINUE,
      SERVICE_CONTROL_INTERROGATE           => :SERVICE_CONTROL_INTERROGATE,
      SERVICE_CONTROL_SHUTDOWN              => :SERVICE_CONTROL_SHUTDOWN,
      SERVICE_CONTROL_PARAMCHANGE           => :SERVICE_CONTROL_PARAMCHANGE,
      SERVICE_CONTROL_NETBINDADD            => :SERVICE_CONTROL_NETBINDADD,
      SERVICE_CONTROL_NETBINDREMOVE         => :SERVICE_CONTROL_NETBINDREMOVE,
      SERVICE_CONTROL_NETBINDENABLE         => :SERVICE_CONTROL_NETBINDENABLE,
      SERVICE_CONTROL_NETBINDDISABLE        => :SERVICE_CONTROL_NETBINDDISABLE,
      SERVICE_CONTROL_DEVICEEVENT           => :SERVICE_CONTROL_DEVICEEVENT,
      SERVICE_CONTROL_HARDWAREPROFILECHANGE => :SERVICE_CONTROL_HARDWAREPROFILECHANGE,
      SERVICE_CONTROL_POWEREVENT            => :SERVICE_CONTROL_POWEREVENT,
      SERVICE_CONTROL_SESSIONCHANGE         => :SERVICE_CONTROL_SESSIONCHANGE,
      SERVICE_CONTROL_PRESHUTDOWN           => :SERVICE_CONTROL_PRESHUTDOWN,
      SERVICE_CONTROL_TIMECHANGE            => :SERVICE_CONTROL_TIMECHANGE,
      SERVICE_CONTROL_TRIGGEREVENT          => :SERVICE_CONTROL_TRIGGEREVENT
    }


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
    UNSAFE_PENDING_STATES    = [SERVICE_START_PENDING, SERVICE_STOP_PENDING]
    FINAL_STATES             = {
      SERVICE_CONTINUE_PENDING => SERVICE_RUNNING,
      SERVICE_PAUSE_PENDING    => SERVICE_PAUSED,
      SERVICE_START_PENDING    => SERVICE_RUNNING,
      SERVICE_STOP_PENDING     => SERVICE_STOPPED
    }
    SERVICE_STATES           = {
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
    # https://docs.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-changeserviceconfig2w
    SERVICE_CONFIG_DESCRIPTION              = 0x00000001
    SERVICE_CONFIG_FAILURE_ACTIONS          = 0x00000002
    SERVICE_CONFIG_DELAYED_AUTO_START_INFO  = 0x00000003
    SERVICE_CONFIG_FAILURE_ACTIONS_FLAG     = 0x00000004
    SERVICE_CONFIG_SERVICE_SID_INFO         = 0x00000005
    SERVICE_CONFIG_REQUIRED_PRIVILEGES_INFO = 0x00000006
    SERVICE_CONFIG_PRESHUTDOWN_INFO         = 0x00000007
    SERVICE_CONFIG_TRIGGER_INFO             = 0x00000008
    SERVICE_CONFIG_PREFERRED_NODE           = 0x00000009
    SERVICE_CONFIG_LAUNCH_PROTECTED         = 0x0000000C
    SERVICE_NO_CHANGE                       = 0xffffffff
    SERVICE_CONFIG_TYPES = {
      SERVICE_CONFIG_DESCRIPTION => :SERVICE_CONFIG_DESCRIPTION,
      SERVICE_CONFIG_FAILURE_ACTIONS => :SERVICE_CONFIG_FAILURE_ACTIONS,
      SERVICE_CONFIG_DELAYED_AUTO_START_INFO => :SERVICE_CONFIG_DELAYED_AUTO_START_INFO,
      SERVICE_CONFIG_FAILURE_ACTIONS_FLAG => :SERVICE_CONFIG_FAILURE_ACTIONS_FLAG,
      SERVICE_CONFIG_SERVICE_SID_INFO => :SERVICE_CONFIG_SERVICE_SID_INFO,
      SERVICE_CONFIG_REQUIRED_PRIVILEGES_INFO => :SERVICE_CONFIG_REQUIRED_PRIVILEGES_INFO,
      SERVICE_CONFIG_PRESHUTDOWN_INFO => :SERVICE_CONFIG_PRESHUTDOWN_INFO,
      SERVICE_CONFIG_TRIGGER_INFO => :SERVICE_CONFIG_TRIGGER_INFO,
      SERVICE_CONFIG_PREFERRED_NODE => :SERVICE_CONFIG_PREFERRED_NODE,
      SERVICE_CONFIG_LAUNCH_PROTECTED => :SERVICE_CONFIG_LAUNCH_PROTECTED,
    }

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

    # Returns true if the service exists, false otherwise.
    #
    # @param [String] service_name name of the service
    def exists?(service_name)
      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_QUERY_STATUS) do |_|
        true
      end
    rescue Puppet::Util::Windows::Error => e
      return false if e.code == ERROR_SERVICE_DOES_NOT_EXIST
      raise e
    end
    module_function :exists?

    # Start a windows service
    #
    # @param [String] service_name name of the service to start
    # @param optional [Integer] timeout the minumum number of seconds to wait before timing out
    def start(service_name, timeout: DEFAULT_TIMEOUT)
      Puppet.debug _("Starting the %{service_name} service. Timeout set to: %{timeout} seconds") % { service_name: service_name, timeout: timeout }

      valid_initial_states = [
        SERVICE_STOP_PENDING,
        SERVICE_STOPPED,
        SERVICE_START_PENDING
      ]

      transition_service_state(service_name, valid_initial_states, SERVICE_RUNNING, timeout) do |service|
        if StartServiceW(service, 0, FFI::Pointer::NULL) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error, _("Failed to start the service")
        end
      end

      Puppet.debug _("Successfully started the %{service_name} service") % { service_name: service_name }
    end
    module_function :start

    # Stop a windows service
    #
    # @param [String] service_name name of the service to stop
    # @param optional [Integer] timeout the minumum number of seconds to wait before timing out
    def stop(service_name, timeout: DEFAULT_TIMEOUT)
      Puppet.debug _("Stopping the %{service_name} service. Timeout set to: %{timeout} seconds") % { service_name: service_name, timeout: timeout }

      valid_initial_states = SERVICE_STATES.keys - [SERVICE_STOPPED]

      transition_service_state(service_name, valid_initial_states, SERVICE_STOPPED, timeout) do |service|
        send_service_control_signal(service, SERVICE_CONTROL_STOP)
      end

      Puppet.debug _("Successfully stopped the %{service_name} service") % { service_name: service_name }
    end
    module_function :stop

    # Resume a paused windows service
    #
    # @param [String] service_name name of the service to resume
    # @param optional [Integer] :timeout the minumum number of seconds to wait before timing out
    def resume(service_name, timeout: DEFAULT_TIMEOUT)
      Puppet.debug _("Resuming the %{service_name} service. Timeout set to: %{timeout} seconds") % { service_name: service_name, timeout: timeout }

      valid_initial_states = [
        SERVICE_PAUSE_PENDING,
        SERVICE_PAUSED,
        SERVICE_CONTINUE_PENDING
      ]

      transition_service_state(service_name, valid_initial_states, SERVICE_RUNNING, timeout) do |service|
        # The SERVICE_CONTROL_CONTINUE signal can only be sent when
        # the service is in the SERVICE_PAUSED state
        wait_on_pending_state(service, SERVICE_PAUSE_PENDING, timeout)

        send_service_control_signal(service, SERVICE_CONTROL_CONTINUE)
      end

      Puppet.debug _("Successfully resumed the %{service_name} service") % { service_name: service_name }
    end
    module_function :resume

    # Query the state of a service using QueryServiceStatusEx
    #
    # @param [string] service_name name of the service to query
    # @return [string] the status of the service
    def service_state(service_name)
      state = nil
      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_QUERY_STATUS) do |service|
        query_status(service) do |status|
          state = SERVICE_STATES[status[:dwCurrentState]]
        end
      end
      if state.nil?
        raise Puppet::Error.new(_("Unknown Service state '%{current_state}' for '%{service_name}'") % { current_state: state.to_s, service_name: service_name})
      end
      state
    end
    module_function :service_state

    # Query the configuration of a service using QueryServiceConfigW
    # or QueryServiceConfig2W
    #
    # @param [String] service_name name of the service to query
    # @return [QUERY_SERVICE_CONFIGW.struct] the configuration of the service
    def service_start_type(service_name)
      start_type = nil
      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_QUERY_CONFIG) do |service|
        query_config(service) do |config|
          start_type = SERVICE_START_TYPES[config[:dwStartType]]
        end
      end
      # if the service has type AUTO_START, check if it's a delayed service
      if start_type == :SERVICE_AUTO_START
        open_service(service_name, SC_MANAGER_CONNECT, SERVICE_QUERY_CONFIG) do |service|
          query_config2(service, SERVICE_CONFIG_DELAYED_AUTO_START_INFO) do |config|
            return :SERVICE_DELAYED_AUTO_START if config[:fDelayedAutostart] == 1
          end
        end
      end
      if start_type.nil?
        raise Puppet::Error.new(_("Unknown start type '%{start_type}' for '%{service_name}'") % { start_type: start_type.to_s, service_name: service_name})
      end
      start_type
    end
    module_function :service_start_type

    # Query the configuration of a service using QueryServiceConfigW
    # to find its current logon account
    #
    # @return [String] logon_account account currently set for the service's logon
    #  in the format "DOMAIN\Account" or ".\Account" if it's a local account
    def logon_account(service_name)
      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_QUERY_CONFIG) do |service|
        query_config(service) do |config|
          return config[:lpServiceStartName].read_arbitrary_wide_string_up_to(Puppet::Util::Windows::ADSI::User::MAX_USERNAME_LENGTH)
        end
      end
    end
    module_function :logon_account

    # Set the startup configuration of a windows service
    #
    # @param [String] service_name the name of the service to modify
    # @param [Hash] options the configuration to be applied. Expected option keys:
    #   - [Integer] startup_type a code corresponding to a start type for
    #       windows service, see the "Service start type codes" section in the
    #       Puppet::Util::Windows::Service file for the list of available codes
    #   - [String] logon_account the account to be used by the service for logon
    #   - [String] logon_password the provided logon_account's password to be used by the service for logon
    #   - [Bool] delayed whether the service should be started with a delay
    def set_startup_configuration(service_name, options: {})
      options[:startup_type] = SERVICE_START_TYPES.key(options[:startup_type]) || SERVICE_NO_CHANGE
      options[:logon_account] = wide_string(options[:logon_account]) || FFI::Pointer::NULL
      options[:logon_password] = wide_string(options[:logon_password]) || FFI::Pointer::NULL

      open_service(service_name, SC_MANAGER_CONNECT, SERVICE_CHANGE_CONFIG) do |service|
        success = ChangeServiceConfigW(
          service,
          SERVICE_NO_CHANGE,        # dwServiceType
          options[:startup_type],   # dwStartType
          SERVICE_NO_CHANGE,        # dwErrorControl
          FFI::Pointer::NULL,       # lpBinaryPathName
          FFI::Pointer::NULL,       # lpLoadOrderGroup
          FFI::Pointer::NULL,       # lpdwTagId
          FFI::Pointer::NULL,       # lpDependencies
          options[:logon_account],  # lpServiceStartName
          options[:logon_password], # lpPassword
          FFI::Pointer::NULL        # lpDisplayName
        )
        if success == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(_("Failed to update service configuration"))
        end
      end

      if options[:startup_type]
        options[:delayed] ||= false
        set_startup_mode_delayed(service_name, options[:delayed])
      end
    end
    module_function :set_startup_configuration

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
      # @return the result of the block
      def open_service(service_name, scm_access, service_access, &block)
        service = FFI::Pointer::NULL_HANDLE

        result = nil
        open_scm(scm_access) do |scm|
          service = OpenServiceW(scm, wide_string(service_name), service_access)
          raise Puppet::Util::Windows::Error.new(_("Failed to open a handle to the service")) if service == FFI::Pointer::NULL_HANDLE
          result = yield service
        end

        result
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
      # Transition the service to the specified state. The block should perform
      # the actual transition.
      #
      # @param [String] service_name the name of the service to transition
      # @param [[Integer]] valid_initial_states an array of valid states that the service can transition from
      # @param [Integer] final_state the state that the service will transition to
      # @param [Integer] timeout the minumum number of seconds to wait before timing out
      def transition_service_state(service_name, valid_initial_states, final_state, timeout, &block)
        service_access = SERVICE_START | SERVICE_STOP | SERVICE_PAUSE_CONTINUE | SERVICE_QUERY_STATUS
        open_service(service_name, SC_MANAGER_CONNECT, service_access) do |service|
          query_status(service) do |status|
            initial_state = status[:dwCurrentState]
            # If the service is already in the final_state, then
            # no further work needs to be done
            if initial_state == final_state
              Puppet.debug _("The service is already in the %{final_state} state. No further work needs to be done.") % { final_state: SERVICE_STATES[final_state] }

              next
            end

            # Check that initial_state corresponds to a valid
            # initial state
            unless valid_initial_states.include?(initial_state)
              valid_initial_states_str = valid_initial_states.map do |state|
                SERVICE_STATES[state]
              end.join(", ")

              raise Puppet::Error, _("The service must be in one of the %{valid_initial_states} states to perform this transition. It is currently in the %{current_state} state.") % { valid_initial_states: valid_initial_states_str, current_state: SERVICE_STATES[initial_state] }
            end

            # Check if there's a pending transition to the final_state. If so, then wait for
            # that transition to finish.
            possible_pending_states = FINAL_STATES.keys.select do |pending_state|
              # SERVICE_RUNNING has two pending states, SERVICE_START_PENDING and
              # SERVICE_CONTINUE_PENDING. That is why we need the #select here
              FINAL_STATES[pending_state] == final_state
            end
            if possible_pending_states.include?(initial_state)
              Puppet.debug _("There is already a pending transition to the %{final_state} state for the %{service_name} service.")  % { final_state: SERVICE_STATES[final_state], service_name: service_name }
              wait_on_pending_state(service, initial_state, timeout)

              next
            end

            # If we are in an unsafe pending state like SERVICE_START_PENDING
            # or SERVICE_STOP_PENDING, then we want to wait for that pending
            # transition to finish before transitioning the service state.
            # The reason we do this is because SERVICE_START_PENDING is when
            # the service thread is being created and initialized, while
            # SERVICE_STOP_PENDING is when the service thread is being cleaned
            # up and destroyed. Thus there is a chance that when the service is
            # in either of these states, its service thread may not yet be ready
            # to perform the state transition (it may not even exist).
            if UNSAFE_PENDING_STATES.include?(initial_state)
              Puppet.debug _("The service is in the %{pending_state} state, which is an unsafe pending state.") % { pending_state: SERVICE_STATES[initial_state] }
              wait_on_pending_state(service, initial_state, timeout)
              initial_state = FINAL_STATES[initial_state]
            end

            Puppet.debug _("Transitioning the %{service_name} service from %{initial_state} to %{final_state}") % { service_name: service_name, initial_state: SERVICE_STATES[initial_state], final_state: SERVICE_STATES[final_state] }

            yield service

            Puppet.debug _("Waiting for the transition to finish")
            wait_on_state_transition(service, initial_state, final_state, timeout)
          end
        end
      rescue => detail
        raise Puppet::Error, _("Failed to transition the %{service_name} service to the %{final_state} state. Detail: %{detail}") % { service_name: service_name, final_state: SERVICE_STATES[final_state], detail: detail }, detail.backtrace
      end
      private :transition_service_state

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
            yield status
          end
        end
      end
      private :query_status

      # @api private
      # perform QueryServiceConfigW on a windows service and return the
      # result
      #
      # @param [:handle] service handle of the service to query
      # @return [QUERY_SERVICE_CONFIGW struct] the result of the query
      def query_config(service, &block)
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
            yield config
          end
        end
      end
      private :query_config

      # @api private
      # perform QueryServiceConfig2W on a windows service and return the
      # result
      #
      # @param [:handle] service handle of the service to query
      # @param [Integer] info_level the configuration information to be queried
      # @return [QUERY_SERVICE_CONFIG2W struct] the result of the query
      def query_config2(service, info_level, &block)
        config = nil
        size_required = nil
        # Fetch the bytes of memory required to be allocated
        # for QueryServiceConfig2W to return succesfully. This
        # is done by sending NULL and 0 for the pointer and size
        # respectively, letting the command fail, then reading the
        # value of pcbBytesNeeded
        FFI::MemoryPointer.new(:lpword) do |bytes_pointer|
          # return value will be false from this call, since it's designed
          # to fail. Just ignore it
          QueryServiceConfig2W(service, info_level, FFI::Pointer::NULL, 0, bytes_pointer)
          size_required = bytes_pointer.read_dword
          FFI::MemoryPointer.new(size_required) do |ssp_ptr|
            # We need to supply the appropriate struct to be created based on
            # the info_level
            case info_level
            when SERVICE_CONFIG_DELAYED_AUTO_START_INFO
              config = SERVICE_DELAYED_AUTO_START_INFO.new(ssp_ptr)
            end
            success = QueryServiceConfig2W(
              service,
              info_level,
              ssp_ptr,
              size_required,
              bytes_pointer
            )
            if success == FFI::WIN32_FALSE
              raise Puppet::Util::Windows::Error.new(_("Service query for %{parameter_name} failed") % { parameter_name: SERVICE_CONFIG_TYPES[info_level] } )
            end
            yield config
          end
        end
      end
      private :query_config2

      # @api private
      # Sets an optional parameter on a service by calling
      # ChangeServiceConfig2W
      #
      # @param [String] service_name name of service
      # @param [Integer] change parameter to change
      # @param [struct] value appropriate struct based on the parameter to change
      def set_optional_parameter(service_name, change, value)
        open_service(service_name, SC_MANAGER_CONNECT, SERVICE_CHANGE_CONFIG) do |service|
          success = ChangeServiceConfig2W(
            service,
            change, # dwInfoLevel
            value,  # lpInfo
          )
          if success == FFI::WIN32_FALSE
            raise Puppet::Util::windows::Error.new(_("Failed to update service %{change} configuration") % { change: change } )
          end
        end
      end
      private :set_optional_parameter

      # @api private
      # Controls the delayed auto-start setting of a service
      #
      # @param [String] service_name name of service
      # @param [Bool] delayed whether the service should be started with a delay or not
      def set_startup_mode_delayed(service_name, delayed)
        delayed_start = SERVICE_DELAYED_AUTO_START_INFO.new
        delayed_start[:fDelayedAutostart] = delayed
        set_optional_parameter(service_name, SERVICE_CONFIG_DELAYED_AUTO_START_INFO, delayed_start)
      end
      private :set_startup_mode_delayed

      # @api private
      # Sends a service control signal to a service
      #
      # @param [:handle] service handle to the service
      # @param [Integer] signal the service control signal to send
      def send_service_control_signal(service, signal)
        FFI::MemoryPointer.new(SERVICE_STATUS.size) do |status_ptr|
          status = SERVICE_STATUS.new(status_ptr)
          if ControlService(service, signal, status) == FFI::WIN32_FALSE
            raise Puppet::Util::Windows::Error, _("Failed to send the %{control_signal} signal to the service. Its current state is %{current_state}. Reason for failure:") % { control_signal: SERVICE_CONTROL_SIGNALS[signal], current_state: SERVICE_STATES[status[:dwCurrentState]] }
          end
        end
      end

      # @api private
      # Waits for a service to transition from one state to
      # another state.
      #
      # @param [:handle] service handle to the service to wait on
      # @param [Integer] initial_state the state that the service is transitioning from.
      # @param [Integer] final_state the state that the service is transitioning to
      # @param [Integer] timeout the minumum number of seconds to wait before timing out
      def wait_on_state_transition(service, initial_state, final_state, timeout)
        # Get the pending state for this transition. Note that SERVICE_RUNNING
        # has two possible pending states, which is why we need this logic.
        if final_state != SERVICE_RUNNING
          pending_state = FINAL_STATES.key(final_state)
        elsif initial_state == SERVICE_STOPPED
          # SERVICE_STOPPED => SERVICE_RUNNING
          pending_state = SERVICE_START_PENDING
        else
          # SERVICE_PAUSED => SERVICE_RUNNING
          pending_state = SERVICE_CONTINUE_PENDING
        end

        # Wait for the transition to finish
        state = nil
        elapsed_time = 0
        while elapsed_time <= timeout

          query_status(service) do |status|
            state = status[:dwCurrentState]
            return if state == final_state
            if state == pending_state
              Puppet.debug _("The service transitioned to the %{pending_state} state.") % { pending_state: SERVICE_STATES[pending_state] }
              wait_on_pending_state(service, pending_state, timeout)
              return
            end
            sleep(1)
            elapsed_time += 1
          end
        end
        # Timed out while waiting for the transition to finish. Raise an error
        # We can still use the state variable read from the FFI struct because
        # FFI creates new Integer objects during an assignment of an integer value
        # stored in an FFI struct. We verified that the '=' operater is safe
        # from the freed memory since the new ruby object created during the
        # assignment will remain in ruby memory and remain immutable and constant.
        raise Puppet::Error, _("Timed out while waiting for the service to transition from %{initial_state} to %{final_state} OR from %{initial_state} to %{pending_state} to %{final_state}. The service's current state is %{current_state}.") % { initial_state: SERVICE_STATES[initial_state], final_state: SERVICE_STATES[final_state], pending_state: SERVICE_STATES[pending_state], current_state: SERVICE_STATES[state] }
      end
      private :wait_on_state_transition

      # @api private
      # Waits for a service to finish transitioning from
      # a pending state. The service must be in the pending state
      # before invoking this routine.
      #
      # @param [:handle] service handle to the service to wait on
      # @param [Integer] pending_state the pending state
      # @param [Integer] timeout the minumum number of seconds to wait before timing out
      def wait_on_pending_state(service, pending_state, timeout)
        final_state = FINAL_STATES[pending_state]

        Puppet.debug _("Waiting for the pending transition to the %{final_state} state to finish.") % { final_state: SERVICE_STATES[final_state] }

        elapsed_time = 0
        last_checkpoint = -1
        loop do
          query_status(service) do |status|
            state = status[:dwCurrentState]
            checkpoint = status[:dwCheckPoint]
            wait_hint = status[:dwWaitHint]
            # Check if our service has finished transitioning to
            # the final_state OR if an unexpected transition
            # has occurred
            return if state == final_state
            unless state == pending_state
              raise Puppet::Error, _("Unexpected transition to the %{current_state} state while waiting for the pending transition from %{pending_state} to %{final_state} to finish.") % { current_state: SERVICE_STATES[state], pending_state: SERVICE_STATES[pending_state], final_state: SERVICE_STATES[final_state] }
            end

            # Check if any progress has been made since our last sleep
            # using the dwCheckPoint. If no progress has been made then
            # check if we've timed out, and raise an error if so
            if checkpoint > last_checkpoint
              elapsed_time = 0
              last_checkpoint = checkpoint
            else
              wait_hint = milliseconds_to_seconds(status[:dwWaitHint])
              timeout = wait_hint < timeout ? timeout : wait_hint

              if elapsed_time >= timeout
                raise Puppet::Error, _("Timed out while waiting for the pending transition from %{pending_state} to %{final_state} to finish. The current state is %{current_state}.") % { pending_state: SERVICE_STATES[pending_state], final_state: SERVICE_STATES[final_state], current_state: SERVICE_STATES[state] }
              end
            end
            wait_time = wait_hint_to_wait_time(wait_hint)
            # Wait a bit before rechecking the service's state
            sleep(wait_time)
            elapsed_time += wait_time
          end
        end
      end
      private :wait_on_pending_state

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
