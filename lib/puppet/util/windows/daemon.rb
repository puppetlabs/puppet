# frozen_string_literal: true

require_relative '../../../puppet/ffi/windows'

module Puppet::Util::Windows
  # The Daemon class, based on the chef/win32-service implementation
  class Daemon
    include Puppet::FFI::Windows::Constants
    extend Puppet::FFI::Windows::Constants

    include Puppet::FFI::Windows::Structs
    extend Puppet::FFI::Windows::Structs

    include Puppet::FFI::Windows::Functions
    extend Puppet::FFI::Windows::Functions

    # Service is not running
    STOPPED = SERVICE_STOPPED

    # Service has received a start signal but is not yet running
    START_PENDING = SERVICE_START_PENDING

    # Service has received a stop signal but is not yet stopped
    STOP_PENDING  = SERVICE_STOP_PENDING

    # Service is running
    RUNNING = SERVICE_RUNNING

    # Service has received a signal to resume but is not yet running
    CONTINUE_PENDING = SERVICE_CONTINUE_PENDING

    # Service has received a signal to pause but is not yet paused
    PAUSE_PENDING = SERVICE_PAUSE_PENDING

    # Service is paused
    PAUSED = SERVICE_PAUSED

    # Service controls

    # Notifies service that it should stop
    CONTROL_STOP = SERVICE_CONTROL_STOP

    # Notifies service that it should pause
    CONTROL_PAUSE = SERVICE_CONTROL_PAUSE

    # Notifies service that it should resume
    CONTROL_CONTINUE = SERVICE_CONTROL_CONTINUE

    # Notifies service that it should return its current status information
    CONTROL_INTERROGATE = SERVICE_CONTROL_INTERROGATE

    # Notifies a service that its parameters have changed
    CONTROL_PARAMCHANGE = SERVICE_CONTROL_PARAMCHANGE

    # Notifies a service that there is a new component for binding
    CONTROL_NETBINDADD = SERVICE_CONTROL_NETBINDADD

    # Notifies a service that a component for binding has been removed
    CONTROL_NETBINDREMOVE = SERVICE_CONTROL_NETBINDREMOVE

    # Notifies a service that a component for binding has been enabled
    CONTROL_NETBINDENABLE = SERVICE_CONTROL_NETBINDENABLE

    # Notifies a service that a component for binding has been disabled
    CONTROL_NETBINDDISABLE = SERVICE_CONTROL_NETBINDDISABLE

    IDLE = 0

    # Misc
    IDLE_CONTROL_CODE = 0
    WAIT_OBJECT_0 = 0
    WAIT_TIMEOUT = 0x00000102
    WAIT_FAILED = 0xFFFFFFFF
    NO_ERROR = 0

    # Wraps SetServiceStatus.
    SetTheServiceStatus = Proc.new do |dwCurrentState, dwWin32ExitCode, dwCheckPoint, dwWaitHint|
      ss = SERVICE_STATUS.new # Current status of the service.

      # Disable control requests until the service is started.
      if dwCurrentState == SERVICE_START_PENDING
        ss[:dwControlsAccepted] = 0
      else
        ss[:dwControlsAccepted] =
          SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN |
          SERVICE_ACCEPT_PAUSE_CONTINUE | SERVICE_ACCEPT_PARAMCHANGE
      end

      # Initialize ss structure.
      ss[:dwServiceType]             = SERVICE_WIN32_OWN_PROCESS
      ss[:dwServiceSpecificExitCode] = 0
      ss[:dwCurrentState]            = dwCurrentState
      ss[:dwWin32ExitCode]           = dwWin32ExitCode
      ss[:dwCheckPoint]              = dwCheckPoint
      ss[:dwWaitHint]                = dwWaitHint

      @@dwServiceState = dwCurrentState

      # Send status of the service to the Service Controller.
      unless SetServiceStatus(@@ssh, ss)
        SetEvent(@@hStopEvent)
      end
    end

    ERROR_CALL_NOT_IMPLEMENTED = 0x78

    # Handles control signals from the service control manager.
    Service_Ctrl_ex = Proc.new do |dwCtrlCode, _dwEventType, _lpEventData, _lpContext|
      @@waiting_control_code = dwCtrlCode;
      return_value = NO_ERROR

      begin
        dwState = SERVICE_RUNNING

        case dwCtrlCode
        when SERVICE_CONTROL_STOP
          dwState = SERVICE_STOP_PENDING
        when SERVICE_CONTROL_SHUTDOWN
          dwState = SERVICE_STOP_PENDING
        when SERVICE_CONTROL_PAUSE
          dwState = SERVICE_PAUSED
        when SERVICE_CONTROL_CONTINUE
          dwState = SERVICE_RUNNING
          # else
          # TODO: Handle other control codes? Retain the current state?
        end

        # Set the status of the service except on interrogation.
        unless dwCtrlCode == SERVICE_CONTROL_INTERROGATE
          SetTheServiceStatus.call(dwState, NO_ERROR, 0, 0)
        end

        # Tell service_main thread to stop.
        if dwCtrlCode == SERVICE_CONTROL_STOP || dwCtrlCode == SERVICE_CONTROL_SHUTDOWN
          if SetEvent(@@hStopEvent) == 0
            SetTheServiceStatus.call(SERVICE_STOPPED, FFI.errno, 0, 0)
          end
        end
      rescue
        return_value = ERROR_CALL_NOT_IMPLEMENTED
      end

      return_value
    end

    # Called by the service control manager after the call to StartServiceCtrlDispatcher.
    Service_Main = FFI::Function.new(:void, [:ulong, :pointer], :blocking => false) do |dwArgc, lpszArgv|
      begin
        # Obtain the name of the service.
        if lpszArgv.address != 0
          argv = lpszArgv.get_array_of_string(0, dwArgc)
          lpszServiceName = argv[0]
        else
          lpszServiceName = ''
        end

        # Args passed to Service.start
        if dwArgc > 1
          @@Argv = argv[1..]
        else
          @@Argv = nil
        end

        # Register the service ctrl handler.
        @@ssh = RegisterServiceCtrlHandlerExW(
          lpszServiceName,
          Service_Ctrl_ex,
          nil
        )

        # No service to stop, no service handle to notify, nothing to do but exit.
        break if @@ssh == 0

        # The service has started.
        SetTheServiceStatus.call(SERVICE_RUNNING, NO_ERROR, 0, 0)

        SetEvent(@@hStartEvent)

        # Main loop for the service.
        while WaitForSingleObject(@@hStopEvent, 1000) != WAIT_OBJECT_0 do
        end

        # Main loop for the service.
        while WaitForSingleObject(@@hStopCompletedEvent, 1000) != WAIT_OBJECT_0 do
        end
      ensure
        # Stop the service.
        SetTheServiceStatus.call(SERVICE_STOPPED, NO_ERROR, 0, 0)
      end
    end

    ThreadProc = FFI::Function.new(:ulong, [:pointer]) do |lpParameter|
      ste = FFI::MemoryPointer.new(SERVICE_TABLE_ENTRYW, 2)

      s = SERVICE_TABLE_ENTRYW.new(ste[0])
      s[:lpServiceName] = FFI::MemoryPointer.from_string('')
      s[:lpServiceProc] = lpParameter

      s = SERVICE_TABLE_ENTRYW.new(ste[1])
      s[:lpServiceName] = nil
      s[:lpServiceProc] = nil

      # No service to step, no service handle, no ruby exceptions, just terminate the thread..
      unless StartServiceCtrlDispatcherW(ste)
        return 1
      end

      return 0
    end

    # This is a shortcut for Daemon.new + Daemon#mainloop.
    #
    def self.mainloop
      self.new.mainloop
    end

    # This is the method that actually puts your code into a loop and allows it
    # to run as a service.  The code that is actually run while in the mainloop
    # is what you defined in your own Daemon#service_main method.
    #
    def mainloop
      @@waiting_control_code = IDLE_CONTROL_CODE
      @@dwServiceState = 0

      # Redirect STDIN, STDOUT and STDERR to the NUL device if they're still
      # associated with a tty. This helps newbs avoid Errno::EBADF errors.
      STDIN.reopen('NUL') if STDIN.isatty
      STDOUT.reopen('NUL') if STDOUT.isatty
      STDERR.reopen('NUL') if STDERR.isatty

      # Calling init here so that init failures never even tries to start the
      # service. Of course that means that init methods must be very quick
      # because the SCM will be receiving no START_PENDING messages while
      # init's running.
      #
      # TODO: Fix?
      service_init() if respond_to?('service_init')

      # Create the event to signal the service to start.
      @@hStartEvent = CreateEventW(nil, 1, 0, nil)

      if @@hStartEvent == 0
        raise SystemCallError.new('CreateEvent', FFI.errno)
      end

      # Create the event to signal the service to stop.
      @@hStopEvent = CreateEventW(nil, 1, 0, nil)

      if @@hStopEvent == 0
        raise SystemCallError.new('CreateEvent', FFI.errno)
      end

      # Create the event to signal the service that stop has completed
      @@hStopCompletedEvent = CreateEventW(nil, 1, 0, nil)

      if @@hStopCompletedEvent == 0
        raise SystemCallError.new('CreateEvent', FFI.errno)
      end

      hThread = CreateThread(nil, 0, ThreadProc, Service_Main, 0, nil)

      if hThread == 0
        raise SystemCallError.new('CreateThread', FFI.errno)
      end

      events = FFI::MemoryPointer.new(:pointer, 2)
      events.put_pointer(0, FFI::Pointer.new(hThread))
      events.put_pointer(FFI::Pointer.size, FFI::Pointer.new(@@hStartEvent))

      while (index = WaitForMultipleObjects(2, events, 0, 1000)) == WAIT_TIMEOUT do
      end

      if index == WAIT_FAILED
        raise SystemCallError.new('WaitForMultipleObjects', FFI.errno)
      end

      # The thread exited, so the show is off.
      if index == WAIT_OBJECT_0
        raise "Service_Main thread exited abnormally"
      end

      thr = Thread.new do
        begin
          while WaitForSingleObject(@@hStopEvent, 1000) == WAIT_TIMEOUT
            # Check to see if anything interesting has been signaled
            case @@waiting_control_code
            when SERVICE_CONTROL_PAUSE
              service_pause() if respond_to?('service_pause')
            when SERVICE_CONTROL_CONTINUE
              service_resume() if respond_to?('service_resume')
            when SERVICE_CONTROL_INTERROGATE
              service_interrogate() if respond_to?('service_interrogate')
            when SERVICE_CONTROL_SHUTDOWN
              service_shutdown() if respond_to?('service_shutdown')
            when SERVICE_CONTROL_PARAMCHANGE
              service_paramchange() if respond_to?('service_paramchange')
            when SERVICE_CONTROL_NETBINDADD
              service_netbindadd() if respond_to?('service_netbindadd')
            when SERVICE_CONTROL_NETBINDREMOVE
              service_netbindremove() if respond_to?('service_netbindremove')
            when SERVICE_CONTROL_NETBINDENABLE
              service_netbindenable() if respond_to?('service_netbindenable')
            when SERVICE_CONTROL_NETBINDDISABLE
              service_netbinddisable() if respond_to?('service_netbinddisable')
            end
            @@waiting_control_code = IDLE_CONTROL_CODE
          end

          service_stop() if respond_to?('service_stop')
        ensure
          SetEvent(@@hStopCompletedEvent)
        end
      end

      if respond_to?('service_main')
        service_main(*@@Argv)
      end

      thr.join
    end

    # Returns the state of the service (as an constant integer) which can be any
    # of the service status constants, e.g. RUNNING, PAUSED, etc.
    #
    # This method is typically used within your service_main method to setup the
    # loop. For example:
    #
    #   class MyDaemon < Daemon
    #     def service_main
    #       while state == RUNNING || state == PAUSED || state == IDLE
    #         # Your main loop here
    #       end
    #     end
    #   end
    #
    # See the Daemon#running? method for an abstraction of the above code.
    #
    def state
      @@dwServiceState
    end

    #
    # Returns whether or not the service is in a running state, i.e. the service
    # status is either RUNNING, PAUSED or IDLE.
    #
    # This is typically used within your service_main method to setup the main
    # loop. For example:
    #
    #    class MyDaemon < Daemon
    #       def service_main
    #          while running?
    #             # Your main loop here
    #          end
    #       end
    #    end
    #
    def running?
      [SERVICE_RUNNING, SERVICE_PAUSED, 0].include?(@@dwServiceState)
    end
  end
end
