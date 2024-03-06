# frozen_string_literal: true

require 'ffi'
require_relative '../../../../puppet/ffi/windows'
require_relative '../../../../puppet/util/windows/string'

module Process
  extend FFI::Library
  extend Puppet::Util::Windows::String

  extend Puppet::FFI::Windows::APITypes
  extend Puppet::FFI::Windows::Functions
  extend Puppet::FFI::Windows::Structs

  include Puppet::FFI::Windows::Constants
  include Puppet::FFI::Windows::Structs

  ProcessInfo = Struct.new(
    'ProcessInfo',
    :process_handle,
    :thread_handle,
    :process_id,
    :thread_id
  )

  private_constant :ProcessInfo

  # Disable popups. This mostly affects the Process.kill method.
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX)

  class << self
    private :SetHandleInformation, :SetErrorMode, :CreateProcessW, :OpenProcess,
            :SetPriorityClass, :CreateProcessWithLogonW, :get_osfhandle, :get_errno

    # Process.create(key => value, ...) => ProcessInfo
    #
    # This is a wrapper for the CreateProcess() function. It executes a process,
    # returning a ProcessInfo struct. It accepts a hash as an argument.
    # There are several primary keys:
    #
    # * command_line     (this or app_name must be present)
    # * app_name         (default: nil)
    # * inherit          (default: false)
    # * process_inherit  (default: false)
    # * thread_inherit   (default: false)
    # * creation_flags   (default: 0)
    # * cwd              (default: Dir.pwd)
    # * startup_info     (default: nil)
    # * environment      (default: nil)
    # * close_handles    (default: true)
    # * with_logon       (default: nil)
    # * domain           (default: nil)
    # * password         (default: nil, mandatory if with_logon)
    #
    # Of these, the 'command_line' or 'app_name' must be specified or an
    # error is raised. Both may be set individually, but 'command_line' should
    # be preferred if only one of them is set because it does not (necessarily)
    # require an explicit path or extension to work.
    #
    # The 'domain' and 'password' options are only relevent in the context
    # of 'with_logon'. If 'with_logon' is set, then the 'password' option is
    # mandatory.
    #
    # The startup_info key takes a hash. Its keys are attributes that are
    # part of the StartupInfo struct, and are generally only meaningful for
    # GUI or console processes. See the documentation on CreateProcess()
    # and the StartupInfo struct on MSDN for more information.
    #
    # * desktop
    # * title
    # * x
    # * y
    # * x_size
    # * y_size
    # * x_count_chars
    # * y_count_chars
    # * fill_attribute
    # * sw_flags
    # * startf_flags
    # * stdin
    # * stdout
    # * stderr
    #
    # Note that the 'stdin', 'stdout' and 'stderr' options can be either Ruby
    # IO objects or file descriptors (i.e. a fileno). However, StringIO objects
    # are not currently supported. Unfortunately, setting these is not currently
    # an option for JRuby.
    #
    # If 'stdin', 'stdout' or 'stderr' are specified, then the +inherit+ value
    # is automatically set to true and the Process::STARTF_USESTDHANDLES flag is
    # automatically OR'd to the +startf_flags+ value.
    #
    # The ProcessInfo struct contains the following members:
    #
    # * process_handle - The handle to the newly created process.
    # * thread_handle  - The handle to the primary thread of the process.
    # * process_id     - Process ID.
    # * thread_id      - Thread ID.
    #
    # If the 'close_handles' option is set to true (the default) then the
    # process_handle and the thread_handle are automatically closed for you
    # before the ProcessInfo struct is returned.
    #
    # If the 'with_logon' option is set, then the process runs the specified
    # executable file in the security context of the specified credentials.

    VALID_KEYS = %i[
      app_name command_line inherit creation_flags cwd environment
      startup_info thread_inherit process_inherit close_handles with_logon
      domain password
    ].freeze

    VALID_SI_KEYS = %i[
      startf_flags desktop title x y x_size y_size x_count_chars
      y_count_chars fill_attribute sw_flags stdin stdout stderr
    ].freeze

    private_constant :VALID_KEYS, :VALID_SI_KEYS

    def create(args)
      # Validate that args is a Hash
      validate_args(args)

      initialize_defaults

      # Validate the keys, and convert symbols and case to lowercase strings.
      validate_keys(args)

      # If the startup_info key is present, validate its subkeys
      validate_startup_info if hash[:startup_info]

      # validates that 'app_name' or 'command_line' is set
      validate_command_line

      if hash[:app_name] && !hash[:command_line]
        hash[:command_line] = hash[:app_name]
        hash[:app_name] = nil
      end

      # Setup stdin, stdout and stderr handlers
      setup_std_handlers

      if logon
        create_process_with_logon
      else
        create_process
      end

      # Automatically close the process and thread handles in the
      # PROCESS_INFORMATION struct unless explicitly told not to.
      if hash[:close_handles]
        FFI::WIN32.CloseHandle(procinfo[:hProcess])
        FFI::WIN32.CloseHandle(procinfo[:hThread])
      end

      ProcessInfo.new(
        procinfo[:hProcess],
        procinfo[:hThread],
        procinfo[:dwProcessId],
        procinfo[:dwThreadId]
      )
    end

    remove_method :setpriority

    # Sets the priority class for the specified process id +int+.
    #
    # The +kind+ parameter is ignored but present for API compatibility.
    # You can only retrieve process information, not process group or user
    # information, so it is effectively always Process::PRIO_PROCESS.
    #
    # Possible +int_priority+ values are:
    #
    # * Process::NORMAL_PRIORITY_CLASS
    # * Process::IDLE_PRIORITY_CLASS
    # * Process::HIGH_PRIORITY_CLASS
    # * Process::REALTIME_PRIORITY_CLASS
    # * Process::BELOW_NORMAL_PRIORITY_CLASS
    # * Process::ABOVE_NORMAL_PRIORITY_CLASS

    def setpriority(kind, int, int_priority)
      raise TypeError unless kind.is_a?(Integer)
      raise TypeError unless int.is_a?(Integer)
      raise TypeError unless int_priority.is_a?(Integer)

      int = Process.pid if int == 0
      handle = OpenProcess(PROCESS_SET_INFORMATION, 0, int)

      if handle == 0
        raise SystemCallError, FFI.errno, "OpenProcess"
      end

      begin
        result = SetPriorityClass(handle, int_priority)
        raise SystemCallError, FFI.errno, "SetPriorityClass" unless result
      ensure
        FFI::WIN32.CloseHandle(handle)
      end

      0
    end

    private

    def initialize_defaults
      @hash = {
        app_name: nil,
        creation_flags: 0,
        close_handles: true
      }
      @si_hash = nil
      @procinfo = nil
    end

    def validate_args(args)
      raise TypeError, 'hash keyword arguments expected' unless args.is_a?(Hash)
    end

    def validate_keys(args)
      args.each do |key, val|
        key = key.to_s.to_sym
        raise ArgumentError, "invalid key '#{key}'" unless VALID_KEYS.include?(key)

        hash[key] = val
      end
    end

    def validate_startup_info
      hash[:startup_info].each do |key, val|
        key = key.to_s.to_sym
        raise ArgumentError, "invalid startup_info key '#{key}'" unless VALID_SI_KEYS.include?(key)

        si_hash[key] = val
      end
    end

    def validate_command_line
      raise ArgumentError, 'command_line or app_name must be specified' unless hash[:app_name] || hash[:command_line]
    end

    def procinfo
      @procinfo ||= PROCESS_INFORMATION.new
    end

    def hash
      @hash ||= {}
    end

    def si_hash
      @si_hash ||= {}
    end

    def app
      wide_string(hash[:app_name])
    end

    def cmd
      wide_string(hash[:command_line])
    end

    def cwd
      wide_string(hash[:cwd])
    end

    def password
      wide_string(hash[:password])
    end

    def logon
      wide_string(hash[:with_logon])
    end

    def domain
      wide_string(hash[:domain])
    end

    def env
      env = hash[:environment]
      return unless env

      env = env.split(File::PATH_SEPARATOR) unless env.respond_to?(:join)
      env = env.map { |e| e + 0.chr }.join('') + 0.chr
      env = wide_string(env) if hash[:with_logon]
      env
    end

    def process_security
      return unless hash[:process_inherit]

      process_security = SECURITY_ATTRIBUTES.new
      process_security[:nLength] = SECURITY_ATTRIBUTES.size
      process_security[:bInheritHandle] = 1
      process_security
    end

    def thread_security
      return unless hash[:thread_inherit]

      thread_security = SECURITY_ATTRIBUTES.new
      thread_security[:nLength] = SECURITY_ATTRIBUTES.size
      thread_security[:bInheritHandle] = 1
      thread_security
    end

    # Automatically handle stdin, stdout and stderr as either IO objects
    # or file descriptors. This won't work for StringIO, however. It also
    # will not work on JRuby because of the way it handles internal file
    # descriptors.
    def setup_std_handlers
      %i[stdin stdout stderr].each do |io|
        next unless si_hash[io]

        handle = if si_hash[io].respond_to?(:fileno)
                   get_osfhandle(si_hash[io].fileno)
                 else
                   get_osfhandle(si_hash[io])
                 end

        if handle == INVALID_HANDLE_VALUE
          ptr = FFI::MemoryPointer.new(:int)

          errno = if get_errno(ptr).zero?
                    ptr.read_int
                  else
                    FFI.errno
                  end

          raise SystemCallError.new('get_osfhandle', errno)
        end

        # Most implementations of Ruby on Windows create inheritable
        # handles by default, but some do not. RF bug #26988.
        bool = SetHandleInformation(
          handle,
          HANDLE_FLAG_INHERIT,
          HANDLE_FLAG_INHERIT
        )

        raise SystemCallError.new('SetHandleInformation', FFI.errno) unless bool

        si_hash[io] = handle
        si_hash[:startf_flags] ||= 0
        si_hash[:startf_flags] |= STARTF_USESTDHANDLES
        hash[:inherit] = true
      end
    end

    def startinfo
      startinfo = STARTUPINFO.new

      return startinfo if si_hash.empty?

      startinfo[:cb]              = startinfo.size
      startinfo[:lpDesktop]       = si_hash[:desktop] if si_hash[:desktop]
      startinfo[:lpTitle]         = si_hash[:title] if si_hash[:title]
      startinfo[:dwX]             = si_hash[:x] if si_hash[:x]
      startinfo[:dwY]             = si_hash[:y] if si_hash[:y]
      startinfo[:dwXSize]         = si_hash[:x_size] if si_hash[:x_size]
      startinfo[:dwYSize]         = si_hash[:y_size] if si_hash[:y_size]
      startinfo[:dwXCountChars]   = si_hash[:x_count_chars] if si_hash[:x_count_chars]
      startinfo[:dwYCountChars]   = si_hash[:y_count_chars] if si_hash[:y_count_chars]
      startinfo[:dwFillAttribute] = si_hash[:fill_attribute] if si_hash[:fill_attribute]
      startinfo[:dwFlags]         = si_hash[:startf_flags] if si_hash[:startf_flags]
      startinfo[:wShowWindow]     = si_hash[:sw_flags] if si_hash[:sw_flags]
      startinfo[:cbReserved2]     = 0
      startinfo[:hStdInput]       = si_hash[:stdin] if si_hash[:stdin]
      startinfo[:hStdOutput]      = si_hash[:stdout] if si_hash[:stdout]
      startinfo[:hStdError]       = si_hash[:stderr] if si_hash[:stderr]
      startinfo
    end

    def create_process_with_logon
      raise ArgumentError, 'password must be specified if with_logon is used' unless password

      hash[:creation_flags] |= CREATE_UNICODE_ENVIRONMENT

      bool = CreateProcessWithLogonW(
        logon,                  # User
        domain,                 # Domain
        password,               # Password
        LOGON_WITH_PROFILE,     # Logon flags
        app,                    # App name
        cmd,                    # Command line
        hash[:creation_flags],  # Creation flags
        env,                    # Environment
        cwd,                    # Working directory
        startinfo,              # Startup Info
        procinfo                # Process Info
      )

      raise SystemCallError.new('CreateProcessWithLogonW', FFI.errno) unless bool
    end

    def create_process
      inherit = hash[:inherit] ? 1 : 0

      bool = CreateProcessW(
        app,                    # App name
        cmd,                    # Command line
        process_security,       # Process attributes
        thread_security,        # Thread attributes
        inherit,                # Inherit handles?
        hash[:creation_flags],  # Creation flags
        env,                    # Environment
        cwd,                    # Working directory
        startinfo,              # Startup Info
        procinfo                # Process Info
      )

      raise SystemCallError.new('CreateProcess', FFI.errno) unless bool
    end
  end
end
