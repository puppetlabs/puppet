require 'puppet/util/windows'

# The Win32 module serves as a namespace only
module Win32
  # The TaskScheduler class encapsulates taskscheduler settings and behavior
  class TaskScheduler
    include Puppet::Util::Windows::String

    require 'ffi'
    extend FFI::Library

    # The error class raised if any task scheduler specific calls fail.
    class Error < Puppet::Util::Windows::Error; end

    private

    class << self
      attr_accessor :com_initialized
    end

    # :stopdoc:
    TASK_TIME_TRIGGER_ONCE            = :TASK_TIME_TRIGGER_ONCE
    TASK_TIME_TRIGGER_DAILY           = :TASK_TIME_TRIGGER_DAILY
    TASK_TIME_TRIGGER_WEEKLY          = :TASK_TIME_TRIGGER_WEEKLY
    TASK_TIME_TRIGGER_MONTHLYDATE     = :TASK_TIME_TRIGGER_MONTHLYDATE
    TASK_TIME_TRIGGER_MONTHLYDOW      = :TASK_TIME_TRIGGER_MONTHLYDOW
    TASK_EVENT_TRIGGER_ON_IDLE        = :TASK_EVENT_TRIGGER_ON_IDLE
    TASK_EVENT_TRIGGER_AT_SYSTEMSTART = :TASK_EVENT_TRIGGER_AT_SYSTEMSTART
    TASK_EVENT_TRIGGER_AT_LOGON       = :TASK_EVENT_TRIGGER_AT_LOGON

    TASK_SUNDAY       = 0x1
    TASK_MONDAY       = 0x2
    TASK_TUESDAY      = 0x4
    TASK_WEDNESDAY    = 0x8
    TASK_THURSDAY     = 0x10
    TASK_FRIDAY       = 0x20
    TASK_SATURDAY     = 0x40
    TASK_FIRST_WEEK   = 1
    TASK_SECOND_WEEK  = 2
    TASK_THIRD_WEEK   = 3
    TASK_FOURTH_WEEK  = 4
    TASK_LAST_WEEK    = 5
    TASK_JANUARY      = 0x1
    TASK_FEBRUARY     = 0x2
    TASK_MARCH        = 0x4
    TASK_APRIL        = 0x8
    TASK_MAY          = 0x10
    TASK_JUNE         = 0x20
    TASK_JULY         = 0x40
    TASK_AUGUST       = 0x80
    TASK_SEPTEMBER    = 0x100
    TASK_OCTOBER      = 0x200
    TASK_NOVEMBER     = 0x400
    TASK_DECEMBER     = 0x800

    TASK_FLAG_INTERACTIVE                  = 0x1
    TASK_FLAG_DELETE_WHEN_DONE             = 0x2
    TASK_FLAG_DISABLED                     = 0x4
    TASK_FLAG_START_ONLY_IF_IDLE           = 0x10
    TASK_FLAG_KILL_ON_IDLE_END             = 0x20
    TASK_FLAG_DONT_START_IF_ON_BATTERIES   = 0x40
    TASK_FLAG_KILL_IF_GOING_ON_BATTERIES   = 0x80
    TASK_FLAG_RUN_ONLY_IF_DOCKED           = 0x100
    TASK_FLAG_HIDDEN                       = 0x200
    TASK_FLAG_RUN_IF_CONNECTED_TO_INTERNET = 0x400
    TASK_FLAG_RESTART_ON_IDLE_RESUME       = 0x800
    TASK_FLAG_SYSTEM_REQUIRED              = 0x1000
    TASK_FLAG_RUN_ONLY_IF_LOGGED_ON        = 0x2000
    TASK_TRIGGER_FLAG_HAS_END_DATE         = 0x1
    TASK_TRIGGER_FLAG_KILL_AT_DURATION_END = 0x2
    TASK_TRIGGER_FLAG_DISABLED             = 0x4

    TASK_MAX_RUN_TIMES = 1440
    TASKS_TO_RETRIEVE  = 5

    # COM

    CLSID_CTask = FFI::WIN32::GUID['148BD520-A2AB-11CE-B11F-00AA00530503']
    IID_ITask = FFI::WIN32::GUID['148BD524-A2AB-11CE-B11F-00AA00530503']
    IID_IPersistFile = FFI::WIN32::GUID['0000010b-0000-0000-C000-000000000046']

    SCHED_S_TASK_READY                    = 0x00041300
    SCHED_S_TASK_RUNNING                  = 0x00041301
    SCHED_S_TASK_HAS_NOT_RUN              = 0x00041303
    SCHED_S_TASK_NOT_SCHEDULED            = 0x00041305
    # HRESULT error codes
    # https://blogs.msdn.com/b/eldar/archive/2007/04/03/a-lot-of-hresult-codes.aspx
    # in Ruby, an 0x8XXXXXXX style HRESULT can be resolved to 2s complement
    # by using "0x8XXXXXXX".to_i(16) - - 0x100000000
    SCHED_E_ACCOUNT_INFORMATION_NOT_SET   = -2147216625 # 0x8004130F
    SCHED_E_NO_SECURITY_SERVICES          = -2147216622 # 0x80041312
    # No mapping between account names and security IDs was done.
    ERROR_NONE_MAPPED                     = -2147023564 # 0x80070534  WIN32 Error CODE 1332 (0x534)

    public

    # :startdoc:

    # Shorthand constants
    IDLE = Puppet::Util::Windows::Process::IDLE_PRIORITY_CLASS
    NORMAL = Puppet::Util::Windows::Process::NORMAL_PRIORITY_CLASS
    HIGH = Puppet::Util::Windows::Process::HIGH_PRIORITY_CLASS
    REALTIME = Puppet::Util::Windows::Process::REALTIME_PRIORITY_CLASS
    BELOW_NORMAL = Puppet::Util::Windows::Process::BELOW_NORMAL_PRIORITY_CLASS
    ABOVE_NORMAL = Puppet::Util::Windows::Process::ABOVE_NORMAL_PRIORITY_CLASS

    ONCE = TASK_TIME_TRIGGER_ONCE
    DAILY = TASK_TIME_TRIGGER_DAILY
    WEEKLY = TASK_TIME_TRIGGER_WEEKLY
    MONTHLYDATE = TASK_TIME_TRIGGER_MONTHLYDATE
    MONTHLYDOW = TASK_TIME_TRIGGER_MONTHLYDOW

    ON_IDLE = TASK_EVENT_TRIGGER_ON_IDLE
    AT_SYSTEMSTART = TASK_EVENT_TRIGGER_AT_SYSTEMSTART
    AT_LOGON = TASK_EVENT_TRIGGER_AT_LOGON
    FIRST_WEEK = TASK_FIRST_WEEK
    SECOND_WEEK = TASK_SECOND_WEEK
    THIRD_WEEK = TASK_THIRD_WEEK
    FOURTH_WEEK = TASK_FOURTH_WEEK
    LAST_WEEK = TASK_LAST_WEEK
    SUNDAY = TASK_SUNDAY
    MONDAY = TASK_MONDAY
    TUESDAY = TASK_TUESDAY
    WEDNESDAY = TASK_WEDNESDAY
    THURSDAY = TASK_THURSDAY
    FRIDAY = TASK_FRIDAY
    SATURDAY = TASK_SATURDAY
    JANUARY = TASK_JANUARY
    FEBRUARY = TASK_FEBRUARY
    MARCH = TASK_MARCH
    APRIL = TASK_APRIL
    MAY = TASK_MAY
    JUNE = TASK_JUNE
    JULY = TASK_JULY
    AUGUST = TASK_AUGUST
    SEPTEMBER = TASK_SEPTEMBER
    OCTOBER = TASK_OCTOBER
    NOVEMBER = TASK_NOVEMBER
    DECEMBER = TASK_DECEMBER

    INTERACTIVE = TASK_FLAG_INTERACTIVE
    DELETE_WHEN_DONE = TASK_FLAG_DELETE_WHEN_DONE
    DISABLED = TASK_FLAG_DISABLED
    START_ONLY_IF_IDLE = TASK_FLAG_START_ONLY_IF_IDLE
    KILL_ON_IDLE_END = TASK_FLAG_KILL_ON_IDLE_END
    DONT_START_IF_ON_BATTERIES = TASK_FLAG_DONT_START_IF_ON_BATTERIES
    KILL_IF_GOING_ON_BATTERIES = TASK_FLAG_KILL_IF_GOING_ON_BATTERIES
    RUN_ONLY_IF_DOCKED = TASK_FLAG_RUN_ONLY_IF_DOCKED
    HIDDEN = TASK_FLAG_HIDDEN
    RUN_IF_CONNECTED_TO_INTERNET = TASK_FLAG_RUN_IF_CONNECTED_TO_INTERNET
    RESTART_ON_IDLE_RESUME = TASK_FLAG_RESTART_ON_IDLE_RESUME
    SYSTEM_REQUIRED = TASK_FLAG_SYSTEM_REQUIRED
    RUN_ONLY_IF_LOGGED_ON = TASK_FLAG_RUN_ONLY_IF_LOGGED_ON

    FLAG_HAS_END_DATE = TASK_TRIGGER_FLAG_HAS_END_DATE
    FLAG_KILL_AT_DURATION_END = TASK_TRIGGER_FLAG_KILL_AT_DURATION_END
    FLAG_DISABLED = TASK_TRIGGER_FLAG_DISABLED

    MAX_RUN_TIMES = TASK_MAX_RUN_TIMES

    # unfortunately MSTask.h does not specify the limits for any settings
    # so these were determined with some experimentation
    # if values too large are written, its suspected there may be internal
    # limits may be exceeded, corrupting the job
    # used for max application name and path values
    MAX_PATH                = 260
    # UNLEN from lmcons.h is 256
    # https://technet.microsoft.com/it-it/library/bb726984(en-us).aspx specifies 104
    MAX_ACCOUNT_LENGTH      = 256
    # command line max length is limited to 8191, choose something high but still enough that we don't blow out CLI
    MAX_PARAMETERS_LENGTH   = 4096
    # in testing, this value could be set to a length of 99999, but saving / loading the task failed
    MAX_COMMENT_LENGTH      = 8192

    # Returns a new TaskScheduler object. If a work_item (and possibly the
    # the trigger) are passed as arguments then a new work item is created and
    # associated with that trigger, although you can still activate other tasks
    # with the same handle.
    #
    # This is really just a bit of convenience. Passing arguments to the
    # constructor is the same as calling TaskScheduler.new plus
    # TaskScheduler#new_work_item.
    #
    def initialize(work_item=nil, trigger=nil)
      @pITS   = nil
      @pITask = nil

      if ! self.class.com_initialized
        Puppet::Util::Windows::COM.InitializeCom()
        self.class.com_initialized = true
      end

      @pITS = COM::TaskScheduler.new
      at_exit do
        begin
          @pITS.Release if @pITS && !@pITS.null?
          @pITS = nil
        rescue
        end
      end

      if work_item
        if trigger
          raise TypeError unless trigger.is_a?(Hash)
          new_work_item(work_item, trigger)
        end
      end
    end

    # Returns an array of scheduled task names.
    #
    def enum
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      array = []

      @pITS.UseInstance(COM::EnumWorkItems, :Enum) do |pIEnum|
        FFI::MemoryPointer.new(:pointer) do |names_array_ptr_ptr|
          FFI::MemoryPointer.new(:win32_ulong) do |fetched_count_ptr|
            # awkward usage, if number requested is available, returns S_OK (0), or if less were returned returns S_FALSE (1)
            while (pIEnum.Next(TASKS_TO_RETRIEVE, names_array_ptr_ptr, fetched_count_ptr) >= Puppet::Util::Windows::COM::S_OK)
              count = fetched_count_ptr.read_win32_ulong
              break if count == 0

              names_array_ptr_ptr.read_com_memory_pointer do |names_array_ptr|
                # iterate over the array of pointers
                name_ptr_ptr = FFI::Pointer.new(:pointer, names_array_ptr)
                for i in 0 ... count
                  name_ptr_ptr[i].read_com_memory_pointer do |name_ptr|
                    array << name_ptr.read_arbitrary_wide_string_up_to(MAX_PATH)
                  end
                end
              end
            end
          end
        end
      end

      array
    end

    alias :tasks :enum

    # Activate the specified task.
    #
    def activate(task)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise TypeError unless task.is_a?(String)

      FFI::MemoryPointer.new(:pointer) do |ptr|
        @pITS.Activate(wide_string(task), IID_ITask, ptr)

        reset_current_task
        @pITask = COM::Task.new(ptr.read_pointer)
      end

      @pITask
    end

    # Delete the specified task name.
    #
    def delete(task)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise TypeError unless task.is_a?(String)

      @pITS.Delete(wide_string(task))

      true
    end

    # Execute the current task.
    #
    def run
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      @pITask.Run
    end

    # Saves the current task. Tasks must be saved before they can be activated.
    # The .job file itself is typically stored in the C:\WINDOWS\Tasks folder.
    #
    # If +file+ (an absolute path) is specified then the job is saved to that
    # file instead. A '.job' extension is recommended but not enforced.
    #
    def save(file = nil)
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise Error.new('Account information must be set on the current task to save it properly.') if !@account_information_set

      reset = true

      begin
        @pITask.QueryInstance(COM::PersistFile) do |pIPersistFile|
          wide_file = wide_string(file)
          pIPersistFile.Save(wide_file, 1)
          pIPersistFile.SaveCompleted(wide_file)
        end
      rescue
        reset = false
      ensure
        reset_current_task if reset
      end
    end

    # Terminate the current task.
    #
    def terminate
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      @pITask.Terminate
    end

    # Set the host on which the various TaskScheduler methods will execute.
    #
    def machine=(host)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise TypeError unless host.is_a?(String)

      @pITS.SetTargetComputer(wide_string(host))

      host
    end

    alias :host= :machine=

    # Sets the +user+ and +password+ for the given task. If the user and
    # password are set properly then true is returned.
    #
    # In some cases the job may be created, but the account information was
    # bad. In this case the task is created but a warning is generated and
    # false is returned.
    #
    # Note that if intending to use SYSTEM, specify an empty user and nil password
    #
    # Calling task.set_account_information('SYSTEM', nil) will generally not
    # work, except for one special case where flags are also set like:
    # task.flags = Win32::TaskScheduler::TASK_FLAG_RUN_ONLY_IF_LOGGED_ON
    #
    # This must be done prior to the 1st save() call for the task to be
    # properly registered and visible through the MMC snap-in / schtasks.exe
    #
    def set_account_information(user, password)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      bool = false

      begin
        if (user.nil? || user=="") && (password.nil? || password=="")
          @pITask.SetAccountInformation(wide_string(""), FFI::Pointer::NULL)
        else
          if user.length > MAX_ACCOUNT_LENGTH
            raise Error.new("User has exceeded maximum allowed length #{MAX_ACCOUNT_LENGTH}")
          end
          user = wide_string(user)
          password = wide_string(password)
          @pITask.SetAccountInformation(user, password)
        end

        @account_information_set = true
        bool = true
      rescue Puppet::Util::Windows::Error => e
        raise e unless e.code == SCHED_E_ACCOUNT_INFORMATION_NOT_SET

        warn 'job created, but password was invalid'
      end

      bool
    end

    # Returns the user associated with the task or nil if no user has yet
    # been associated with the task.
    #
    def account_information
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      # default under certain failures
      user = nil

      begin
        FFI::MemoryPointer.new(:pointer) do |ptr|
          @pITask.GetAccountInformation(ptr)
          ptr.read_com_memory_pointer do |str_ptr|
            user = str_ptr.read_arbitrary_wide_string_up_to(MAX_ACCOUNT_LENGTH) if ! str_ptr.null?
          end
        end
      rescue Puppet::Util::Windows::Error => e
        raise e unless e.code == SCHED_E_ACCOUNT_INFORMATION_NOT_SET ||
                       e.code == SCHED_E_NO_SECURITY_SERVICES ||
                       e.code == ERROR_NONE_MAPPED
      end

      user
    end

    # Returns the name of the application associated with the task.
    #
    def application_name
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      app = nil

      FFI::MemoryPointer.new(:pointer) do |ptr|
        @pITask.GetApplicationName(ptr)

        ptr.read_com_memory_pointer do |str_ptr|
          app = str_ptr.read_arbitrary_wide_string_up_to(MAX_PATH) if ! str_ptr.null?
        end
      end

      app
    end

    # Sets the application name associated with the task.
    #
    def application_name=(app)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise TypeError unless app.is_a?(String)

      # the application name is written to a .job file on disk, so is subject to path limitations
      if app.length > MAX_PATH
        raise Error.new("Application name has exceeded maximum allowed length #{MAX_PATH}")
      end
      @pITask.SetApplicationName(wide_string(app))

      app
    end

    # Returns the command line parameters for the task.
    #
    def parameters
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      param = nil

      FFI::MemoryPointer.new(:pointer) do |ptr|
        @pITask.GetParameters(ptr)

        ptr.read_com_memory_pointer do |str_ptr|
          param = str_ptr.read_arbitrary_wide_string_up_to(MAX_PARAMETERS_LENGTH) if ! str_ptr.null?
        end
      end

      param
    end

    # Sets the parameters for the task. These parameters are passed as command
    # line arguments to the application the task will run. To clear the command
    # line parameters set it to an empty string.
    #
    def parameters=(param)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise TypeError unless param.is_a?(String)

      if param.length > MAX_PARAMETERS_LENGTH
        raise Error.new("Parameters has exceeded maximum allowed length #{MAX_PARAMETERS_LENGTH}")
      end

      @pITask.SetParameters(wide_string(param))

      param
    end

    # Returns the working directory for the task.
    #
    def working_directory
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      dir = nil

      FFI::MemoryPointer.new(:pointer) do |ptr|
        @pITask.GetWorkingDirectory(ptr)

        ptr.read_com_memory_pointer do |str_ptr|
          dir = str_ptr.read_arbitrary_wide_string_up_to(MAX_PATH) if ! str_ptr.null?
        end
      end

      dir
    end

    # Sets the working directory for the task.
    #
    def working_directory=(dir)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise TypeError unless dir.is_a?(String)

      if dir.length > MAX_PATH
        raise Error.new("Working directory has exceeded maximum allowed length #{MAX_PATH}")
      end

      @pITask.SetWorkingDirectory(wide_string(dir))

      dir
    end

    # Returns the task's priority level. Possible values are 'idle',
    # 'normal', 'high', 'realtime', 'below_normal', 'above_normal',
    # and 'unknown'.
    #
    def priority
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      priority_name = ''

      FFI::MemoryPointer.new(:dword, 1) do |ptr|
        @pITask.GetPriority(ptr)

        pri = ptr.read_dword
        if (pri & IDLE) != 0
          priority_name = 'idle'
        elsif (pri & NORMAL) != 0
          priority_name = 'normal'
        elsif (pri & HIGH) != 0
          priority_name = 'high'
        elsif (pri & REALTIME) != 0
          priority_name = 'realtime'
        elsif (pri & BELOW_NORMAL) != 0
          priority_name = 'below_normal'
        elsif (pri & ABOVE_NORMAL) != 0
          priority_name = 'above_normal'
        else
          priority_name = 'unknown'
        end
      end

      priority_name
    end

    # Sets the priority of the task. The +priority+ should be a numeric
    # priority constant value.
    #
    def priority=(priority)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise TypeError unless priority.is_a?(Numeric)

      @pITask.SetPriority(priority)

      priority
    end

    # Creates a new work item (scheduled job) with the given +trigger+. The
    # trigger variable is a hash of options that define when the scheduled
    # job should run.
    #
    def new_work_item(task, trigger)
      raise TypeError unless trigger.is_a?(Hash)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?

      # I'm working around github issue #1 here.
      enum.each{ |name|
        if name.downcase == task.downcase + '.job'
          raise Error.new("task '#{task}' already exists")
        end
      }

      FFI::MemoryPointer.new(:pointer) do |ptr|
        @pITS.NewWorkItem(wide_string(task), CLSID_CTask, IID_ITask, ptr)

        reset_current_task
        @pITask = COM::Task.new(ptr.read_pointer)

        FFI::MemoryPointer.new(:word, 1) do |trigger_index_ptr|
          # Without the 'enum.include?' check above the code segfaults here if the
          # task already exists. This should probably be handled properly instead
          # of simply avoiding the issue.

          @pITask.UseInstance(COM::TaskTrigger, :CreateTrigger, trigger_index_ptr) do |pITaskTrigger|
            populate_trigger(pITaskTrigger, trigger)
          end
        end
      end

      # preload task with the SYSTEM account
      # empty string '' means 'SYSTEM' per MSDN, so default it
      # given an account is necessary for creation of a task
      # note that a user may set SYSTEM explicitly, but that has problems
      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381276(v=vs.85).aspx
      set_account_information('', nil)

      @pITask
    end

    alias :new_task :new_work_item

    # Returns the number of triggers associated with the active task.
    #
    def trigger_count
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      count = 0

      FFI::MemoryPointer.new(:word, 1) do |ptr|
        @pITask.GetTriggerCount(ptr)
        count = ptr.read_word
      end

      count
    end

    # Deletes the trigger at the specified index.
    #
    def delete_trigger(index)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      @pITask.DeleteTrigger(index)
      index
    end

    # Returns a hash that describes the trigger at the given index for the
    # current task.
    #
    def trigger(index)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      trigger = {}

      @pITask.UseInstance(COM::TaskTrigger, :GetTrigger, index) do |pITaskTrigger|
        FFI::MemoryPointer.new(COM::TASK_TRIGGER.size) do |task_trigger_ptr|
          pITaskTrigger.GetTrigger(task_trigger_ptr)
          trigger = populate_hash_from_trigger(COM::TASK_TRIGGER.new(task_trigger_ptr))
        end
      end

      trigger
    end

    # Sets the trigger for the currently active task.
    #
    def trigger=(trigger)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise TypeError unless trigger.is_a?(Hash)

      FFI::MemoryPointer.new(:word, 1) do |trigger_index_ptr|
        # Without the 'enum.include?' check above the code segfaults here if the
        # task already exists. This should probably be handled properly instead
        # of simply avoiding the issue.

        @pITask.UseInstance(COM::TaskTrigger, :CreateTrigger, trigger_index_ptr) do |pITaskTrigger|
          populate_trigger(pITaskTrigger, trigger)
        end
      end

      trigger
    end

    # Adds a trigger at the specified index.
    #
    def add_trigger(index, trigger)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise TypeError unless trigger.is_a?(Hash)

      @pITask.UseInstance(COM::TaskTrigger, :GetTrigger, index) do |pITaskTrigger|
        populate_trigger(pITaskTrigger, trigger)
      end
    end

    # Returns the flags (integer) that modify the behavior of the work item. You
    # must OR the return value to determine the flags yourself.
    #
    def flags
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      flags = 0

      FFI::MemoryPointer.new(:dword, 1) do |ptr|
        @pITask.GetFlags(ptr)
        flags = ptr.read_dword
      end

      flags
    end

    # Sets an OR'd value of flags that modify the behavior of the work item.
    #
    def flags=(flags)
      raise Error.new('No current task scheduler. ITaskScheduler is NULL.') if @pITS.nil?
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      @pITask.SetFlags(flags)
      flags
    end

    # Returns the status of the currently active task. Possible values are
    # 'ready', 'running', 'not scheduled' or 'unknown'.
    #
    def status
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      st = nil

      FFI::MemoryPointer.new(:hresult, 1) do |ptr|
        @pITask.GetStatus(ptr)
        st = ptr.read_hresult
      end

      case st
        when SCHED_S_TASK_READY
           status = 'ready'
        when SCHED_S_TASK_RUNNING
           status = 'running'
        when SCHED_S_TASK_NOT_SCHEDULED
           status = 'not scheduled'
        else
           status = 'unknown'
      end

      status
    end

    # Returns the exit code from the last scheduled run.
    #
    def exit_code
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      status = 0

      begin
        FFI::MemoryPointer.new(:dword, 1) do |ptr|
          @pITask.GetExitCode(ptr)
          status = ptr.read_dword
        end
      rescue Puppet::Util::Windows::Error => e
        raise e unless e.code == SCHED_S_TASK_HAS_NOT_RUN
      end

      status
    end

    # Returns the comment associated with the task, if any.
    #
    def comment
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      comment = nil

      FFI::MemoryPointer.new(:pointer) do |ptr|
        @pITask.GetComment(ptr)

        ptr.read_com_memory_pointer do |str_ptr|
          comment = str_ptr.read_arbitrary_wide_string_up_to(MAX_COMMENT_LENGTH) if ! str_ptr.null?
        end
      end

      comment
    end

    # Sets the comment for the task.
    #
    def comment=(comment)
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise TypeError unless comment.is_a?(String)

      if comment.length > MAX_COMMENT_LENGTH
        raise Error.new("Comment has exceeded maximum allowed length #{MAX_COMMENT_LENGTH}")
      end

      @pITask.SetComment(wide_string(comment))
      comment
    end

    # Returns the name of the user who created the task.
    #
    def creator
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      creator = nil

      FFI::MemoryPointer.new(:pointer) do |ptr|
        @pITask.GetCreator(ptr)

        ptr.read_com_memory_pointer do |str_ptr|
          creator = str_ptr.read_arbitrary_wide_string_up_to(MAX_ACCOUNT_LENGTH) if ! str_ptr.null?
        end
      end

      creator
    end

    # Sets the creator for the task.
    #
    def creator=(creator)
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise TypeError unless creator.is_a?(String)

      if creator.length > MAX_ACCOUNT_LENGTH
        raise Error.new("Creator has exceeded maximum allowed length #{MAX_ACCOUNT_LENGTH}")
      end


      @pITask.SetCreator(wide_string(creator))
      creator
    end

    # Returns a Time object that indicates the next time the task will run.
    #
    def next_run_time
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      time = nil

      FFI::MemoryPointer.new(WIN32::SYSTEMTIME.size) do |ptr|
        @pITask.GetNextRunTime(ptr)
        time = WIN32::SYSTEMTIME.new(ptr).to_local_time
      end

      time
    end

    # Returns a Time object indicating the most recent time the task ran or
    # nil if the task has never run.
    #
    def most_recent_run_time
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      time = nil

      begin
        FFI::MemoryPointer.new(WIN32::SYSTEMTIME.size) do |ptr|
          @pITask.GetMostRecentRunTime(ptr)
          time = WIN32::SYSTEMTIME.new(ptr).to_local_time
        end
      rescue Puppet::Util::Windows::Error => e
        raise e unless e.code == SCHED_S_TASK_HAS_NOT_RUN
      end

      time
    end

    # Returns the maximum length of time, in milliseconds, that the task
    # will run before terminating.
    #
    def max_run_time
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?

      max_run_time = nil

      FFI::MemoryPointer.new(:dword, 1) do |ptr|
        @pITask.GetMaxRunTime(ptr)
        max_run_time = ptr.read_dword
      end

      max_run_time
    end

    # Sets the maximum length of time, in milliseconds, that the task can run
    # before terminating. Returns the value you specified if successful.
    #
    def max_run_time=(max_run_time)
      raise Error.new('No currently active task. ITask is NULL.') if @pITask.nil?
      raise TypeError unless max_run_time.is_a?(Numeric)

      @pITask.SetMaxRunTime(max_run_time)
      max_run_time
    end

    # Returns whether or not the scheduled task exists.
    def exists?(job_name)
      # task name comparison is case insensitive
      tasks.any? { |name| name.casecmp(job_name + '.job') == 0 }
    end

    private

    # :stopdoc:

    # Used for the new_work_item method
    ValidTriggerKeys = [
      'end_day',
      'end_month',
      'end_year',
      'flags',
      'minutes_duration',
      'minutes_interval',
      'random_minutes_interval',
      'start_day',
      'start_hour',
      'start_minute',
      'start_month',
      'start_year',
      'trigger_type',
      'type'
    ]

    ValidTypeKeys = [
       'days_interval',
       'weeks_interval',
       'days_of_week',
       'months',
       'days',
       'weeks'
    ]

    # Private method that validates keys, and converts all keys to lowercase
    # strings.
    #
    def transform_and_validate(hash)
      new_hash = {}

      hash.each{ |key, value|
        key = key.to_s.downcase
        if key == 'type'
          new_type_hash = {}
          raise ArgumentError unless value.is_a?(Hash)
          value.each{ |subkey, subvalue|
            subkey = subkey.to_s.downcase
            if ValidTypeKeys.include?(subkey)
              new_type_hash[subkey] = subvalue
            else
              raise ArgumentError, "Invalid type key '#{subkey}'"
            end
          }
          new_hash[key] = new_type_hash
        else
          if ValidTriggerKeys.include?(key)
            new_hash[key] = value
          else
            raise ArgumentError, "Invalid key '#{key}'"
          end
        end
      }

      new_hash
    end

    private

    def reset_current_task
      # Ensure that COM reference is decremented properly
      @pITask.Release if @pITask && ! @pITask.null?
      @pITask = nil
      @account_information_set = false
    end

    def populate_trigger(task_trigger, trigger)
      raise TypeError unless task_trigger.is_a?(COM::TaskTrigger)
      trigger = transform_and_validate(trigger)

      FFI::MemoryPointer.new(COM::TASK_TRIGGER.size) do |trigger_ptr|
        FFI::MemoryPointer.new(COM::TRIGGER_TYPE_UNION.size) do |trigger_type_union_ptr|
          trigger_type_union = COM::TRIGGER_TYPE_UNION.new(trigger_type_union_ptr)

          tmp = trigger['type'].is_a?(Hash) ? trigger['type'] : nil
          case trigger['trigger_type']
            when :TASK_TIME_TRIGGER_DAILY
              if tmp && tmp['days_interval']
                trigger_type_union[:Daily][:DaysInterval] = tmp['days_interval']
              end
            when :TASK_TIME_TRIGGER_WEEKLY
              if tmp && tmp['weeks_interval'] && tmp['days_of_week']
                trigger_type_union[:Weekly][:WeeksInterval] = tmp['weeks_interval']
                trigger_type_union[:Weekly][:rgfDaysOfTheWeek] = tmp['days_of_week']
              end
            when :TASK_TIME_TRIGGER_MONTHLYDATE
              if tmp && tmp['months'] && tmp['days']
                trigger_type_union[:MonthlyDate][:rgfDays] = tmp['days']
                trigger_type_union[:MonthlyDate][:rgfMonths] = tmp['months']
              end
            when :TASK_TIME_TRIGGER_MONTHLYDOW
              if tmp && tmp['weeks'] && tmp['days_of_week'] && tmp['months']
                trigger_type_union[:MonthlyDOW][:wWhichWeek] = tmp['weeks']
                trigger_type_union[:MonthlyDOW][:rgfDaysOfTheWeek] = tmp['days_of_week']
                trigger_type_union[:MonthlyDOW][:rgfMonths] = tmp['months']
              end
            when :TASK_TIME_TRIGGER_ONCE
              # Do nothing. The Type member of the TASK_TRIGGER struct is ignored.
            else
              raise Error.new("Unknown trigger type #{trigger['trigger_type']}")
          end

          trigger_struct = COM::TASK_TRIGGER.new(trigger_ptr)
          trigger_struct[:cbTriggerSize] = COM::TASK_TRIGGER.size
          now = Time.now
          trigger_struct[:wBeginYear] = trigger['start_year'] || now.year
          trigger_struct[:wBeginMonth] = trigger['start_month'] || now.month
          trigger_struct[:wBeginDay] = trigger['start_day'] || now.day
          trigger_struct[:wEndYear] = trigger['end_year'] || 0
          trigger_struct[:wEndMonth] = trigger['end_month'] || 0
          trigger_struct[:wEndDay] = trigger['end_day'] || 0
          trigger_struct[:wStartHour] = trigger['start_hour'] || 0
          trigger_struct[:wStartMinute] = trigger['start_minute'] || 0
          trigger_struct[:MinutesDuration] = trigger['minutes_duration'] || 0
          trigger_struct[:MinutesInterval] = trigger['minutes_interval'] || 0
          trigger_struct[:rgFlags] = trigger['flags'] || 0
          trigger_struct[:TriggerType] = trigger['trigger_type'] || :TASK_TIME_TRIGGER_ONCE
          trigger_struct[:Type] = trigger_type_union
          trigger_struct[:wRandomMinutesInterval] = trigger['random_minutes_interval'] || 0

          task_trigger.SetTrigger(trigger_struct)
        end
      end
    end

    def populate_hash_from_trigger(task_trigger)
      raise TypeError unless task_trigger.is_a?(COM::TASK_TRIGGER)

      trigger = {
        'start_year' => task_trigger[:wBeginYear],
        'start_month' => task_trigger[:wBeginMonth],
        'start_day' => task_trigger[:wBeginDay],
        'end_year' => task_trigger[:wEndYear],
        'end_month' => task_trigger[:wEndMonth],
        'end_day' => task_trigger[:wEndDay],
        'start_hour' => task_trigger[:wStartHour],
        'start_minute' => task_trigger[:wStartMinute],
        'minutes_duration' => task_trigger[:MinutesDuration],
        'minutes_interval' => task_trigger[:MinutesInterval],
        'flags' => task_trigger[:rgFlags],
        'trigger_type' => task_trigger[:TriggerType],
        'random_minutes_interval' => task_trigger[:wRandomMinutesInterval]
      }

      case task_trigger[:TriggerType]
        when :TASK_TIME_TRIGGER_DAILY
          trigger['type'] = { 'days_interval' => task_trigger[:Type][:Daily][:DaysInterval] }
        when :TASK_TIME_TRIGGER_WEEKLY
          trigger['type'] = {
            'weeks_interval' => task_trigger[:Type][:Weekly][:WeeksInterval],
            'days_of_week' => task_trigger[:Type][:Weekly][:rgfDaysOfTheWeek]
          }
        when :TASK_TIME_TRIGGER_MONTHLYDATE
          trigger['type'] = {
            'days' => task_trigger[:Type][:MonthlyDate][:rgfDays],
            'months' => task_trigger[:Type][:MonthlyDate][:rgfMonths]
          }
        when :TASK_TIME_TRIGGER_MONTHLYDOW
          trigger['type'] = {
            'weeks' => task_trigger[:Type][:MonthlyDOW][:wWhichWeek],
            'days_of_week' => task_trigger[:Type][:MonthlyDOW][:rgfDaysOfTheWeek],
            'months' => task_trigger[:Type][:MonthlyDOW][:rgfMonths]
          }
        when :TASK_TIME_TRIGGER_ONCE
          trigger['type'] = { 'once' => nil }
        else
          raise Error.new("Unknown trigger type #{task_trigger[:TriggerType]}")
      end

      trigger
    end

    module COM
      extend FFI::Library
      private

      com = Puppet::Util::Windows::COM

      public

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381811(v=vs.85).aspx
      ITaskScheduler = com::Interface[com::IUnknown,
        FFI::WIN32::GUID['148BD527-A2AB-11CE-B11F-00AA00530503'],

        SetTargetComputer: [[:lpcwstr], :hresult],
        # LPWSTR *
        GetTargetComputer: [[:pointer], :hresult],
        # IEnumWorkItems **
        Enum: [[:pointer], :hresult],
        # LPCWSTR, REFIID, IUnknown **
        Activate: [[:lpcwstr, :pointer, :pointer], :hresult],
        Delete: [[:lpcwstr], :hresult],
        # LPCWSTR, REFCLSID, REFIID, IUnknown **
        NewWorkItem: [[:lpcwstr, :pointer, :pointer, :pointer], :hresult],
        # LPCWSTR, IScheduledWorkItem *
        AddWorkItem: [[:lpcwstr, :pointer], :hresult],
        # LPCWSTR, REFIID
        IsOfType: [[:lpcwstr, :pointer], :hresult]
      ]

      TaskScheduler = com::Factory[ITaskScheduler,
        FFI::WIN32::GUID['148BD52A-A2AB-11CE-B11F-00AA00530503']]

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380706(v=vs.85).aspx
      IEnumWorkItems = com::Interface[com::IUnknown,
        FFI::WIN32::GUID['148BD528-A2AB-11CE-B11F-00AA00530503'],

        # ULONG, LPWSTR **, ULONG *
        Next: [[:win32_ulong, :pointer, :pointer], :hresult],
        Skip: [[:win32_ulong], :hresult],
        Reset: [[], :hresult],
        # IEnumWorkItems ** ppEnumWorkItems
        Clone: [[:pointer], :hresult]
      ]

      EnumWorkItems = com::Instance[IEnumWorkItems]

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381216(v=vs.85).aspx
      IScheduledWorkItem = com::Interface[com::IUnknown,
        FFI::WIN32::GUID['a6b952f0-a4b1-11d0-997d-00aa006887ec'],

        # WORD *, ITaskTrigger **
        CreateTrigger: [[:pointer, :pointer], :hresult],
        DeleteTrigger: [[:word], :hresult],
        # WORD *
        GetTriggerCount: [[:pointer], :hresult],
        # WORD, ITaskTrigger **
        GetTrigger: [[:word, :pointer], :hresult],
        # WORD, LPWSTR *
        GetTriggerString: [[:word, :pointer], :hresult],
        # LPSYSTEMTIME, LPSYSTEMTIME, WORD *, LPSYSTEMTIME *
        GetRunTimes: [[:pointer, :pointer, :pointer, :pointer], :hresult],
        # SYSTEMTIME *
        GetNextRunTime: [[:pointer], :hresult],
        SetIdleWait: [[:word, :word], :hresult],
        # WORD *, WORD *
        GetIdleWait: [[:pointer, :pointer], :hresult],
        Run: [[], :hresult],
        Terminate: [[], :hresult],
        EditWorkItem: [[:hwnd, :dword], :hresult],
        # SYSTEMTIME *
        GetMostRecentRunTime: [[:pointer], :hresult],
        # HRESULT *
        GetStatus: [[:pointer], :hresult],
        GetExitCode: [[:pdword], :hresult],
        SetComment: [[:lpcwstr], :hresult],
        # LPWSTR *
        GetComment: [[:pointer], :hresult],
        SetCreator: [[:lpcwstr], :hresult],
        # LPWSTR *
        GetCreator: [[:pointer], :hresult],
        # WORD, BYTE[]
        SetWorkItemData: [[:word, :buffer_in], :hresult],
        # WORD *, BYTE **
        GetWorkItemData: [[:pointer, :pointer], :hresult],
        SetErrorRetryCount: [[:word], :hresult],
        # WORD *
        GetErrorRetryCount: [[:pointer], :hresult],
        SetErrorRetryInterval: [[:word], :hresult],
        # WORD *
        GetErrorRetryInterval: [[:pointer], :hresult],
        SetFlags: [[:dword], :hresult],
        # WORD *
        GetFlags: [[:pointer], :hresult],
        SetAccountInformation: [[:lpcwstr, :lpcwstr], :hresult],
        # LPWSTR *
        GetAccountInformation: [[:pointer], :hresult]
      ]

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381311(v=vs.85).aspx
      ITask = com::Interface[IScheduledWorkItem,
        FFI::WIN32::GUID['148BD524-A2AB-11CE-B11F-00AA00530503'],

        SetApplicationName: [[:lpcwstr], :hresult],
        # LPWSTR *
        GetApplicationName: [[:pointer], :hresult],
        SetParameters: [[:lpcwstr], :hresult],
        # LPWSTR *
        GetParameters: [[:pointer], :hresult],
        SetWorkingDirectory: [[:lpcwstr], :hresult],
        # LPWSTR *
        GetWorkingDirectory: [[:pointer], :hresult],
        SetPriority: [[:dword], :hresult],
        # DWORD *
        GetPriority: [[:pointer], :hresult],
        SetTaskFlags: [[:dword], :hresult],
        # DWORD *
        GetTaskFlags: [[:pointer], :hresult],
        SetMaxRunTime: [[:dword], :hresult],
        # DWORD *
        GetMaxRunTime: [[:pointer], :hresult]
      ]

      Task = com::Instance[ITask]

      # https://msdn.microsoft.com/en-us/library/windows/desktop/ms688695(v=vs.85).aspx
      IPersist = com::Interface[com::IUnknown,
        FFI::WIN32::GUID['0000010c-0000-0000-c000-000000000046'],
        # CLSID *
        GetClassID: [[:pointer], :hresult]
      ]

      # https://msdn.microsoft.com/en-us/library/windows/desktop/ms687223(v=vs.85).aspx
      IPersistFile = com::Interface[IPersist,
        FFI::WIN32::GUID['0000010b-0000-0000-C000-000000000046'],

        IsDirty: [[], :hresult],
        Load: [[:lpcolestr, :dword], :hresult],
        Save: [[:lpcolestr, :win32_bool], :hresult],
        SaveCompleted: [[:lpcolestr], :hresult],
        # LPOLESTR *
        GetCurFile: [[:pointer], :hresult]
      ]

      PersistFile = com::Instance[IPersistFile]

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381864(v=vs.85).aspx
      ITaskTrigger = com::Interface[com::IUnknown,
        FFI::WIN32::GUID['148BD52B-A2AB-11CE-B11F-00AA00530503'],

        SetTrigger: [[:pointer], :hresult],
        GetTrigger: [[:pointer], :hresult],
        GetTriggerString: [[:pointer], :hresult]
      ]

      TaskTrigger = com::Instance[ITaskTrigger]

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383620(v=vs.85).aspx
      # The TASK_TRIGGER_TYPE field of the TASK_TRIGGER structure determines
      # which member of the TRIGGER_TYPE_UNION field to use.
      TASK_TRIGGER_TYPE = enum(
        :TASK_TIME_TRIGGER_ONCE, 0,             # Ignore the Type field
        :TASK_TIME_TRIGGER_DAILY, 1,
        :TASK_TIME_TRIGGER_WEEKLY, 2,
        :TASK_TIME_TRIGGER_MONTHLYDATE, 3,
        :TASK_TIME_TRIGGER_MONTHLYDOW,  4,
        :TASK_EVENT_TRIGGER_ON_IDLE, 5,         # Ignore the Type field
        :TASK_EVENT_TRIGGER_AT_SYSTEMSTART, 6,  # Ignore the Type field
        :TASK_EVENT_TRIGGER_AT_LOGON, 7         # Ignore the Type field
      )

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446857(v=vs.85).aspx
      class DAILY < FFI::Struct
        layout :DaysInterval, :word
      end

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384014(v=vs.85).aspx
      class WEEKLY < FFI::Struct
        layout :WeeksInterval, :word,
               :rgfDaysOfTheWeek, :word
      end

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381918(v=vs.85).aspx
      class MONTHLYDATE < FFI::Struct
        layout :rgfDays, :dword,
               :rgfMonths, :word
      end

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381918(v=vs.85).aspx
      class MONTHLYDOW < FFI::Struct
        layout :wWhichWeek, :word,
               :rgfDaysOfTheWeek, :word,
               :rgfMonths, :word
      end

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384002(v=vs.85).aspx
      class TRIGGER_TYPE_UNION < FFI::Union
        layout :Daily, DAILY,
               :Weekly, WEEKLY,
               :MonthlyDate, MONTHLYDATE,
               :MonthlyDOW, MONTHLYDOW
      end

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383618(v=vs.85).aspx
      class TASK_TRIGGER < FFI::Struct
        layout :cbTriggerSize, :word,            # Structure size.
               :Reserved1, :word,                # Reserved. Must be zero.
               :wBeginYear, :word,               # Trigger beginning date year.
               :wBeginMonth, :word,              # Trigger beginning date month.
               :wBeginDay, :word,                # Trigger beginning date day.
               :wEndYear, :word,                 # Optional trigger ending date year.
               :wEndMonth, :word,                # Optional trigger ending date month.
               :wEndDay, :word,                  # Optional trigger ending date day.
               :wStartHour, :word,               # Run bracket start time hour.
               :wStartMinute, :word,             # Run bracket start time minute.
               :MinutesDuration, :dword,         # Duration of run bracket.
               :MinutesInterval, :dword,         # Run bracket repetition interval.
               :rgFlags, :dword,                 # Trigger flags.
               :TriggerType, TASK_TRIGGER_TYPE,  # Trigger type.
               :Type, TRIGGER_TYPE_UNION,        # Trigger data.
               :Reserved2, :word,                # Reserved. Must be zero.
               :wRandomMinutesInterval, :word    # Maximum number of random minutes after start time
      end
    end
  end
end
