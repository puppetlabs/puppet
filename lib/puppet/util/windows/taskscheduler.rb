require 'windows/com'
require 'windows/unicode'
require 'windows/error'
require 'windows/process'
require 'windows/msvcrt/buffer'

# The Win32 module serves as a namespace only
module Win32
  # The TaskScheduler class encapsulates taskscheduler settings and behavior
  class TaskScheduler
    include Windows::COM
    include Windows::Unicode
    include Windows::Process
    include Windows::Error
    include Windows::MSVCRT::Buffer

    # The version of the win32-taskscheduler library
    VERSION = '0.2.2'

    # The error class raised if any task scheduler specific calls fail.
    class Error < StandardError; end

    private

    # :stopdoc:

    TASK_TIME_TRIGGER_ONCE            = 0
    TASK_TIME_TRIGGER_DAILY           = 1
    TASK_TIME_TRIGGER_WEEKLY          = 2
    TASK_TIME_TRIGGER_MONTHLYDATE     = 3
    TASK_TIME_TRIGGER_MONTHLYDOW      = 4
    TASK_EVENT_TRIGGER_ON_IDLE        = 5
    TASK_EVENT_TRIGGER_AT_SYSTEMSTART = 6
    TASK_EVENT_TRIGGER_AT_LOGON       = 7

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

    CLSCTX_INPROC_SERVER  = 0x1
    CLSID_CTask = [0x148BD520,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03].pack('LSSC8')
    CLSID_CTaskScheduler = [0x148BD52A,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03].pack('LSSC8')
    IID_ITaskScheduler = [0x148BD527,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03].pack('LSSC8')
    IID_ITask = [0x148BD524,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03].pack('LSSC8')
    IID_IPersistFile = [0x0000010b,0x0000,0x0000,0xC0,0x00,0x00,0x00,0x00,0x00,0x00,0x46].pack('LSSC8')

    public

    # :startdoc:

    # Shorthand constants

    IDLE = IDLE_PRIORITY_CLASS
    NORMAL = NORMAL_PRIORITY_CLASS
    HIGH = HIGH_PRIORITY_CLASS
    REALTIME = REALTIME_PRIORITY_CLASS
    BELOW_NORMAL = BELOW_NORMAL_PRIORITY_CLASS
    ABOVE_NORMAL = ABOVE_NORMAL_PRIORITY_CLASS

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

      hr = CoInitialize(0)

      if SUCCEEDED(hr)
        ptr = 0.chr * 4

        hr = CoCreateInstance(
          CLSID_CTaskScheduler,
          nil,
          CLSCTX_INPROC_SERVER,
          IID_ITaskScheduler,
          ptr
        )

        if FAILED(hr)
          raise Error, get_last_error
        end

        @pITS = ptr.unpack('L').first
      else
        raise Error, get_last_error
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
      raise Error, 'null pointer' if @pITS.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 24

      memcpy(lpVtbl, @pITS, 4)
      memcpy(table, lpVtbl.unpack('L').first, 24)
      table = table.unpack('L*')

      enum = Win32::API::Function.new(table[5], 'PP', 'L')

      ptr = 0.chr * 4
      hr  = enum.call(@pITS, ptr)

      raise Error, get_last_error if hr != S_OK

      pIEnum = ptr.unpack('L').first
      lpVtbl = 0.chr * 4
      table  = 0.chr * 16

      memcpy(lpVtbl, pIEnum, 4)
      memcpy(table, lpVtbl.unpack('L').first, 16)
      table = table.unpack('L*')

      _next   = Win32::API::Function.new(table[3], 'PLPP', 'L')
      release = Win32::API::Function.new(table[2], 'P', 'L')

      array = []
      fetched_tasks = 0.chr * 4
      pnames = 0.chr * 4

      while (_next.call(pIEnum, TASKS_TO_RETRIEVE, pnames, fetched_tasks) >= S_OK) &&
        (fetched_tasks.unpack('L').first != 0)

        tasks = fetched_tasks.unpack('L').first
        names = 0.chr * 4 * tasks
        memcpy(names, pnames.unpack('L').first, 4 * tasks)

        for i in 0 ... tasks
          str = 0.chr * 256
          wcscpy(str, names[i*4, 4].unpack('L').first)
          array.push(wide_to_multi(str))
          CoTaskMemFree(names[i*4, 4].unpack('L').first)
        end

        CoTaskMemFree(pnames.unpack('L').first)
      end

      release.call(pIEnum)

      array
    end

    alias :tasks :enum

    # Activate the specified task.
    #
    def activate(task)
      raise Error, 'null pointer' if @pITS.nil?
      raise TypeError unless task.is_a?(String)

      task = multi_to_wide(task)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 28

      memcpy(lpVtbl, @pITS, 4)
      memcpy(table, lpVtbl.unpack('L').first, 28)
      table = table.unpack('L*')

      activate = Win32::API::Function.new(table[6], 'PPPP', 'L')

      ptr = 0.chr * 4
      hr  = activate.call(@pITS, task, IID_ITask, ptr)

      if hr != S_OK
        raise Error, get_last_error
      end

      @pITask = ptr.unpack('L').first
    end

    # Delete the specified task name.
    #
    def delete(task)
      raise Error, 'null pointer' if @pITS.nil?
      raise TypeError unless task.is_a?(String)

      task = multi_to_wide(task)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 32

      memcpy(lpVtbl, @pITS, 4)
      memcpy(table, lpVtbl.unpack('L').first, 32)
      table = table.unpack('L*')

      delete = Win32::API::Function.new(table[7], 'PP', 'L')

      hr = delete.call(@pITS,task)

      if hr != S_OK
        raise Error, get_last_error
      end
    end

    # Execute the current task.
    #
    def run
      raise Error, 'null pointer' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 52

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 52)
      table = table.unpack('L*')

      run = Win32::API::Function.new(table[12], 'P', 'L')

      hr = run.call(@pITask)

      if hr != S_OK
        raise Error,get_last_error
      end
    end

    # Saves the current task. Tasks must be saved before they can be activated.
    # The .job file itself is typically stored in the C:\WINDOWS\Tasks folder.
    #
    # If +file+ (an absolute path) is specified then the job is saved to that
    # file instead. A '.job' extension is recommended but not enforced.
    #
    # Note that calling TaskScheduler#save also resets the TaskScheduler object
    # so that there is no currently active task.
    #
    def save(file = nil)
      raise Error, 'null pointer' if @pITask.nil?
      file = multi_to_wide(file) if file

      lpVtbl = 0.chr * 4
      table  = 0.chr * 12

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 12)
      table = table.unpack('L*')

      queryinterface = Win32::API::Function.new(table[0],'PPP','L')
      release = Win32::API::Function.new(table[2],'P','L')

      ptr = 0.chr * 4

      hr = queryinterface.call(@pITask, IID_IPersistFile, ptr)

      if hr != S_OK
        raise Error, get_last_error
      end

      pIPersistFile = ptr.unpack('L').first

      lpVtbl = 0.chr * 4
      table = 0.chr * 28

      memcpy(lpVtbl, pIPersistFile,4)
      memcpy(table, lpVtbl.unpack('L').first, 28)
      table = table.unpack('L*')

      save = Win32::API::Function.new(table[6],'PPL','L')
      release = Win32::API::Function.new(table[2],'P','L')

      hr = save.call(pIPersistFile,file,1)

      if hr != S_OK
        raise Error,get_last_error
      end

      release.call(pIPersistFile)

      CoUninitialize()
      hr = CoInitialize(nil)

      if hr >= 0
        ptr = 0.chr * 4

        hr = CoCreateInstance(
          CLSID_CTaskScheduler,
          nil,
          CLSCTX_INPROC_SERVER,
          IID_ITaskScheduler,
          ptr
        )

        if hr != S_OK
          CoUninitialize()
          raise Error, get_last_error
        end

        @pITS = ptr.unpack('L').first
      else
        raise Error,get_last_error
      end

      release.call(@pITask)
      @pITask = nil
    end

    # Terminate the current task.
    #
    def terminate
      raise Error, 'null pointer' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 56

      memcpy(lpVtbl,@pITask,4)
      memcpy(table,lpVtbl.unpack('L').first,56)
      table = table.unpack('L*')

      teriminate = Win32::API::Function.new(table[13],'P','L')
      hr = teriminate.call(@pITask)

      if hr != S_OK
        raise Error,get_last_error
      end
    end

    # Set the host on which the various TaskScheduler methods will execute.
    #
    def machine=(host)
      raise Error, 'null pointer' if @pITS.nil?
      raise TypeError unless host.is_a?(String)

      host_w = multi_to_wide(host)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 16

      memcpy(lpVtbl, @pITS, 4)
      memcpy(table, lpVtbl.unpack('L').first, 16)
      table = table.unpack('L*')

      setTargetComputer = Win32::API::Function.new(table[3], 'PP', 'L')

      hr = setTargetComputer.call(@pITS, host_w)

      if hr != S_OK
        raise Error, get_last_error
      end

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
    def set_account_information(user, password)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 124

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 124)
      table = table.unpack('L*')

      setAccountInformation = Win32::API::Function.new(table[30],'PPP','L')

      if (user.nil? || user=="") && (password.nil? || password=="")
        hr = setAccountInformation.call(@pITask, multi_to_wide(""), nil)
      else
        user = multi_to_wide(user)
        password = multi_to_wide(password)
        hr = setAccountInformation.call(@pITask, user, password)
      end

      bool = true

      case hr
        when S_OK
          return true
        when 0x80070005 # E_ACCESSDENIED
          raise Error, 'access denied'
        when 0x80070057 # E_INVALIDARG
          raise Error, 'invalid argument'
        when 0x8007000E # E_OUTOFMEMORY
          raise Error, 'out of memory'
        when 0x80041312 # SCHED_E_NO_SECURITY_SERVICES
          raise Error, 'no security services on this platform'
        when 0x80041314 # SCHED_E_UNSUPPORTED_ACCOUNT_OPTION
          raise Error, 'unsupported account option'
        when 0x8004130F # SCHED_E_ACCOUNT_INFORMATION_NOT_SET
          warn 'job created, but password was invalid'
          bool = false
        else
          raise Error, 'unknown error'
      end

      bool
    end

    # Returns the user associated with the task or nil if no user has yet
    # been associated with the task.
    #
    def account_information
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 128

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table,lpVtbl.unpack('L').first, 128)
      table = table.unpack('L*')

      getAccountInformation = Win32::API::Function.new(table[31], 'PP', 'L')

      ptr = 0.chr * 4
      hr = getAccountInformation.call(@pITask, ptr)

      if hr == 0x8004130F # SCHED_E_ACCOUNT_INFORMATION_NOT_SET
        user = nil
      elsif hr >= 0 && hr != 0x80041312 # SCHED_E_NO_SECURITY_SERVICES
        str = 0.chr * 256
        wcscpy(str, ptr.unpack('L').first)
        CoTaskMemFree(ptr.unpack('L').first)
        user = wide_to_multi(str)
      else
        CoTaskMemFree(p.unpack('L').first)
        raise Error,get_last_error(hr)
      end

      user
    end

    # Returns the name of the application associated with the task.
    #
    def application_name
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 136

      memcpy(lpVtbl, @pITask,4)
      memcpy(table, lpVtbl.unpack('L').first, 136)
      table = table.unpack('L*')

      getApplicationName = Win32::API::Function.new(table[33],'PP','L')

      ptr = 0.chr * 4
      hr  = getApplicationName.call(@pITask, ptr)

      if hr >= S_OK
        str = 0.chr * 256
        wcscpy(str, ptr.unpack('L').first)
        app = wide_to_multi(str)
        CoTaskMemFree(ptr.unpack('L').first)
      else
        raise Error, get_last_error
      end

      app
    end

    # Sets the application name associated with the task.
    #
    def application_name=(app)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless app.is_a?(String)

      app_w = multi_to_wide(app)

      lpVtbl = 0.chr * 4
      table = 0.chr * 132
      memcpy(lpVtbl,@pITask,4)
      memcpy(table,lpVtbl.unpack('L').first,132)
      table = table.unpack('L*')
      setApplicationName = Win32::API::Function.new(table[32],'PP','L')

      hr = setApplicationName.call(@pITask,app_w)

      if hr != S_OK
        raise Error,get_last_error(hr)
      end

      app
    end

    # Returns the command line parameters for the task.
    #
    def parameters
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 144

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 144)
      table = table.unpack('L*')

      getParameters = Win32::API::Function.new(table[35], 'PP', 'L')
      ptr = 0.chr * 4
      hr = getParameters.call(@pITask, ptr)

      if hr >= S_OK
        str = 0.chr * 256
        wcscpy(str, ptr.unpack('L').first)
        param = wide_to_multi(str)
        CoTaskMemFree(ptr.unpack('L').first)
      else
        raise Error, get_last_error
      end

      param
    end

    # Sets the parameters for the task. These parameters are passed as command
    # line arguments to the application the task will run. To clear the command
    # line parameters set it to an empty string.
    #
    def parameters=(param)
      raise Error, 'null pointer(ts_set_parameters)' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless param.is_a?(String)

      param_w = multi_to_wide(param)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 140

      memcpy(lpVtbl,@pITask,4)
      memcpy(table,lpVtbl.unpack('L').first,140)
      table = table.unpack('L*')

      setParameters = Win32::API::Function.new(table[34],'PP','L')
      hr = setParameters.call(@pITask,param_w)

      if hr != S_OK
        raise Error, get_last_error(hr)
      end

      param
    end

    # Returns the working directory for the task.
    #
    def working_directory
      raise Error,"fatal error: null pointer(ts_get_parameters)" if @pITS.nil?
      raise Error,"No currently active task" if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 152

      memcpy(lpVtbl, @pITask,4)
      memcpy(table, lpVtbl.unpack('L').first,152)
      table = table.unpack('L*')

      getWorkingDirectory = Win32::API::Function.new(table[37],'PP','L')

      ptr = 0.chr * 4
      hr  = getWorkingDirectory.call(@pITask, ptr)

      if hr >= S_OK
        str = 0.chr * 256
        wcscpy(str, ptr.unpack('L').first)
        dir = wide_to_multi(str)
        CoTaskMemFree(ptr.unpack('L').first)
      else
        raise Error, get_last_error
      end

      dir
    end

    # Sets the working directory for the task.
    #
    def working_directory=(dir)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless dir.is_a?(String)

      dir_w = multi_to_wide(dir)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 148

      memcpy(lpVtbl, @pITask,4)
      memcpy(table, lpVtbl.unpack('L').first, 148)
      table = table.unpack('L*')

      setWorkingDirectory = Win32::API::Function.new(table[36], 'PP', 'L')
      hr = setWorkingDirectory.call(@pITask, dir_w)

      if hr != S_OK
        raise Error, get_last_error(hr)
      end

      dir
    end

    # Returns the task's priority level. Possible values are 'idle',
    # 'normal', 'high', 'realtime', 'below_normal', 'above_normal',
    # and 'unknown'.
    #
    def priority
      raise Error, 'null pointer(ts_get_priority)' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 160

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 160)
      table = table.unpack('L*')

      getPriority = Win32::API::Function.new(table[39], 'PP', 'L')

      ptr = 0.chr * 4
      hr  = getPriority.call(@pITask, ptr)

      if hr >= S_OK
        pri = ptr.unpack('L').first
        if (pri & IDLE_PRIORITY_CLASS) != 0
          priority = 'idle'
        elsif (pri & NORMAL_PRIORITY_CLASS) != 0
          priority = 'normal'
        elsif (pri & HIGH_PRIORITY_CLASS) != 0
          priority = 'high'
        elsif (pri & REALTIME_PRIORITY_CLASS) != 0
          priority = 'realtime'
        elsif (pri & BELOW_NORMAL_PRIORITY_CLASS) != 0
          priority = 'below_normal'
        elsif (pri & ABOVE_NORMAL_PRIORITY_CLASS) != 0
          priority = 'above_normal'
        else
          priority = 'unknown'
        end
      else
        raise Error, get_last_error
      end

      priority
    end

    # Sets the priority of the task. The +priority+ should be a numeric
    # priority constant value.
    #
    def priority=(priority)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless priority.is_a?(Numeric)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 156

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 156)
      table = table.unpack('L*')

      setPriority = Win32::API::Function.new(table[38], 'PL', 'L')
      hr = setPriority.call(@pITask, priority)

      if hr != S_OK
        raise Error, get_last_error(hr)
      end

      priority
    end

    # Creates a new work item (scheduled job) with the given +trigger+. The
    # trigger variable is a hash of options that define when the scheduled
    # job should run.
    #
    def new_work_item(task, trigger)
      raise TypeError unless trigger.is_a?(Hash)
      raise Error, 'null pointer' if @pITS.nil?

      # I'm working around github issue #1 here.
      enum.each{ |name|
        if name.downcase == task.downcase + '.job'
          raise Error, "task '#{task}' already exists"
        end
      }

      trigger = transform_and_validate(trigger)

      if @pITask
        lpVtbl = 0.chr * 4
        table  = 0.chr * 12

        memcpy(lpVtbl, @pITask, 4)
        memcpy(table, lpVtbl.unpack('L').first, 12)
        table = table.unpack('L*')

        release = Win32::API::Function.new(table[2], 'P', 'L')
        release.call(@pITask)

        @pITask = nil
      end

      task = multi_to_wide(task)
      lpVtbl = 0.chr * 4
      table  = 0.chr * 36

      memcpy(lpVtbl, @pITS, 4)
      memcpy(table, lpVtbl.unpack('L').first, 36)
      table = table.unpack('L*')

      newWorkItem = Win32::API::Function.new(table[8], 'PPPPP', 'L')

      ptr = 0.chr * 4

      hr = newWorkItem.call(@pITS, task, CLSID_CTask, IID_ITask, ptr)

      if FAILED(hr)
        raise Error, get_last_error
      end

      @pITask = ptr.unpack('L').first
      lpVtbl = 0.chr * 4
      table  = 0.chr * 16

      # Without the 'enum.include?' check above the code segfaults here if the
      # task already exists. This should probably be handled properly instead
      # of simply avoiding the issue.

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 16)
      table = table.unpack('L*')

      createTrigger = Win32::API::Function.new(table[3], 'PPP', 'L')
      p1 = 0.chr * 4
      p2 = 0.chr * 4

      hr = createTrigger.call(@pITask, p1, p2)

      if hr != S_OK
        raise Error, get_last_error
      end

      pITaskTrigger = p2.unpack('L').first
      lpVtbl = 0.chr * 4
      table  = 0.chr * 16

      memcpy(lpVtbl, pITaskTrigger, 4)
      memcpy(table, lpVtbl.unpack('L').first, 16)
      table = table.unpack('L*')

      release = Win32::API::Function.new(table[2], 'P', 'L')
      setTrigger = Win32::API::Function.new(table[3], 'PP', 'L')

      type1 = 0
      type2 = 0
      tmp = trigger['type']
      tmp = nil unless tmp.is_a?(Hash)

      case trigger['trigger_type']
        when TASK_TIME_TRIGGER_DAILY
          if tmp && tmp['days_interval']
            type1 = [tmp['days_interval'],0].pack('SS').unpack('L').first
          end
        when TASK_TIME_TRIGGER_WEEKLY
          if tmp && tmp['weeks_interval'] && tmp['days_of_week']
            type1 = [tmp['weeks_interval'],tmp['days_of_week']].pack('SS').unpack('L').first
          end
        when TASK_TIME_TRIGGER_MONTHLYDATE
          if tmp && tmp['months'] && tmp['days']
            type2 = [tmp['months'],0].pack('SS').unpack('L').first
            type1 = tmp['days']
          end
        when TASK_TIME_TRIGGER_MONTHLYDOW
          if tmp && tmp['weeks'] && tmp['days_of_week'] && tmp['months']
            type1 = [tmp['weeks'],tmp['days_of_week']].pack('SS').unpack('L').first
            type2 = [tmp['months'],0].pack('SS').unpack('L').first
          end
        when TASK_TIME_TRIGGER_ONCE
          # Do nothing. The Type member of the TASK_TRIGGER struct is ignored.
        else
          raise Error, 'Unknown trigger type'
      end

      pTrigger = [
        48,
        0,
        trigger['start_year'] || 0,
        trigger['start_month'] || 0,
        trigger['start_day'] || 0,
        trigger['end_year'] || 0,
        trigger['end_month'] || 0,
        trigger['end_day'] || 0,
        trigger['start_hour'] || 0,
        trigger['start_minute'] || 0,
        trigger['minutes_duration'] || 0,
        trigger['minutes_interval'] || 0,
        trigger['flags'] || 0,
        trigger['trigger_type'] || 0,
        type1,
        type2,
        0,
        trigger['random_minutes_interval'] || 0
      ].pack('S10L4LLSS')

      hr = setTrigger.call(pITaskTrigger, pTrigger)

      if hr != S_OK
        raise Error, get_last_error
      end

      release.call(pITaskTrigger)
    end

    alias :new_task :new_work_item

    # Returns the number of triggers associated with the active task.
    #
    def trigger_count
      raise Error, "null pointer" if @pITS.nil?
      raise Error, "No currently active task" if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 24

      memcpy(lpVtbl, @pITask,4)
      memcpy(table, lpVtbl.unpack('L').first, 24)
      table = table.unpack('L*')

      getTriggerCount = Win32::API::Function.new(table[5], 'PP', 'L')
      ptr = 0.chr * 4
      hr  = getTriggerCount.call(@pITask, ptr)

      if hr >= S_OK
        count = ptr.unpack('L').first
      else
        raise Error, get_last_error
      end

      count
    end

    # Returns a string that describes the current trigger at the specified
    # index for the active task.
    #
    # Example: "At 7:14 AM every day, starting 4/11/2009"
    #
    def trigger_string(index)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless index.is_a?(Numeric)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 32

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 32)
      table = table.unpack('L*')

      getTriggerString = Win32::API::Function.new(table[7], 'PLP', 'L')
      ptr = 0.chr * 4
      hr  = getTriggerString.call(@pITask, index, ptr)

      if hr == S_OK
        str = 0.chr * 256
        wcscpy(str, ptr.unpack('L').first)
        trigger = wide_to_multi(str)
        CoTaskMemFree(ptr.unpack('L').first)
      else
        raise Error, get_last_error
      end

      trigger
    end

    # Deletes the trigger at the specified index.
    #
    def delete_trigger(index)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 20

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 20)
      table = table.unpack('L*')

      deleteTrigger = Win32::API::Function.new(table[4], 'PL', 'L')
      hr = deleteTrigger.call(@pITask,index)

      if hr != S_OK
        raise Error, get_last_error
      end

      index
    end

    # Returns a hash that describes the trigger at the given index for the
    # current task.
    #
    def trigger(index)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 28

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 28)
      table = table.unpack('L*')

      getTrigger = Win32::API::Function.new(table[6], 'PLP', 'L')
      ptr = 0.chr * 4
      hr = getTrigger.call(@pITask, index, ptr)

      if hr != S_OK
        raise Error, get_last_error
      end

      pITaskTrigger = ptr.unpack('L').first
      lpVtbl = 0.chr * 4
      table  = 0.chr * 20

      memcpy(lpVtbl, pITaskTrigger, 4)
      memcpy(table, lpVtbl.unpack('L').first, 20)
      table = table.unpack('L*')

      release = Win32::API::Function.new(table[2], 'P', 'L')
      getTrigger = Win32::API::Function.new(table[4], 'PP', 'L')

      pTrigger = [48].pack('S') + 0.chr * 46
      hr = getTrigger.call(pITaskTrigger, pTrigger)

      if hr != S_OK
        error = get_last_error
        release.call(pITaskTrigger)
        raise Error, error
      end

      tr = pTrigger.unpack('S10L4LLSS')

      trigger = {}
      trigger['start_year'] = tr[2]
      trigger['start_month'] = tr[3]
      trigger['start_day'] = tr[4]
      trigger['end_year'] = tr[5]
      trigger['end_month'] = tr[6]
      trigger['end_day'] = tr[7]
      trigger['start_hour'] = tr[8]
      trigger['start_minute'] = tr[9]
      trigger['minutes_duration'] = tr[10]
      trigger['minutes_interval'] = tr[11]
      trigger['flags'] = tr[12]
      trigger['trigger_type'] = tr[13]
      trigger['random_minutes_interval'] = tr[17]

      case tr[13]
        when TASK_TIME_TRIGGER_DAILY
          tmp = {}
          tmp['days_interval'] = [tr[14]].pack('L').unpack('SS').first
          trigger['type'] = tmp
        when TASK_TIME_TRIGGER_WEEKLY
          tmp = {}
          tmp['weeks_interval'],tmp['days_of_week'] = [tr[14]].pack('L').unpack('SS')
          trigger['type'] = tmp
        when TASK_TIME_TRIGGER_MONTHLYDATE
          tmp = {}
          tmp['days'] = tr[14]
          tmp['months'] = [tr[15]].pack('L').unpack('SS').first
          trigger['type'] = tmp
        when TASK_TIME_TRIGGER_MONTHLYDOW
          tmp = {}
          tmp['weeks'],tmp['days_of_week'] = [tr[14]].pack('L').unpack('SS')
          tmp['months'] = [tr[15]].pack('L').unpack('SS').first
          trigger['type'] = tmp
        when TASK_TIME_TRIGGER_ONCE
          tmp = {}
          tmp['once'] = nil
          trigger['type'] = tmp
        else
          raise Error, 'Unknown trigger type'
      end

      release.call(pITaskTrigger)

      trigger
    end

    # Sets the trigger for the currently active task.
    #
    def trigger=(trigger)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless trigger.is_a?(Hash)

      trigger = transform_and_validate(trigger)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 16

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 16)
      table = table.unpack('L*')

      createTrigger = Win32::API::Function.new(table[3], 'PPP', 'L')

      p1 = 0.chr * 4
      p2 = 0.chr * 4

      hr = createTrigger.call(@pITask, p1, p2)

      if hr != S_OK
        raise Error, get_last_error
      end

      pITaskTrigger = p2.unpack('L').first
      lpVtbl = 0.chr * 4
      table  = 0.chr * 16

      memcpy(lpVtbl, pITaskTrigger, 4)
      memcpy(table, lpVtbl.unpack('L').first, 16)
      table = table.unpack('L*')

      release = Win32::API::Function.new(table[2], 'P', 'L')
      setTrigger = Win32::API::Function.new(table[3], 'PP', 'L')

      type1 = 0
      type2 = 0
      tmp = trigger['type']
      tmp = nil unless tmp.is_a?(Hash)

      case trigger['trigger_type']
        when TASK_TIME_TRIGGER_DAILY
          if tmp && tmp['days_interval']
            type1 = [tmp['days_interval'],0].pack('SS').unpack('L').first
          end
        when TASK_TIME_TRIGGER_WEEKLY
          if tmp && tmp['weeks_interval'] && tmp['days_of_week']
            type1 = [tmp['weeks_interval'],tmp['days_of_week']].pack('SS').unpack('L').first
          end
        when TASK_TIME_TRIGGER_MONTHLYDATE
          if tmp && tmp['months'] && tmp['days']
            type2 = [tmp['months'],0].pack('SS').unpack('L').first
            type1 = tmp['days']
          end
        when TASK_TIME_TRIGGER_MONTHLYDOW
          if tmp && tmp['weeks'] && tmp['days_of_week'] && tmp['months']
            type1 = [tmp['weeks'],tmp['days_of_week']].pack('SS').unpack('L').first
            type2 = [tmp['months'],0].pack('SS').unpack('L').first
          end
        when TASK_TIME_TRIGGER_ONCE
          # Do nothing. The Type member of the TASK_TRIGGER struct is ignored.
        else
          raise Error, 'Unknown trigger type'
      end

      pTrigger = [
        48,
        0,
        trigger['start_year'] || 0,
        trigger['start_month'] || 0,
        trigger['start_day'] || 0,
        trigger['end_year'] || 0,
        trigger['end_month'] || 0,
        trigger['end_day'] || 0,
        trigger['start_hour'] || 0,
        trigger['start_minute'] || 0,
        trigger['minutes_duration'] || 0,
        trigger['minutes_interval'] || 0,
        trigger['flags'] || 0,
        trigger['trigger_type'] || 0,
        type1,
        type2,
        0,
        trigger['random_minutes_interval'] || 0
      ].pack('S10L4LLSS')

      hr = setTrigger.call(pITaskTrigger, pTrigger)

      if hr != S_OK
        raise Error, get_last_error
      end

      release.call(pITaskTrigger)

      trigger
    end

    # Adds a trigger at the specified index.
    #
    def add_trigger(index, trigger)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless trigger.is_a?(Hash)

      trigger = transform_and_validate(trigger)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 28

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 28)
      table = table.unpack('L*')

      getTrigger = Win32::API::Function.new(table[6], 'PLP', 'L')
      ptr = 0.chr * 4
      hr = getTrigger.call(@pITask, index, ptr)

      if hr != S_OK
        raise Error, get_last_error
      end

      pITaskTrigger = ptr.unpack('L').first
      lpVtbl = 0.chr * 4
      table = 0.chr * 16

      memcpy(lpVtbl, pITaskTrigger,4)
      memcpy(table, lpVtbl.unpack('L').first,16)
      table = table.unpack('L*')

      release = Win32::API::Function.new(table[2], 'P', 'L')
      setTrigger = Win32::API::Function.new(table[3], 'PP', 'L')

      type1 = 0
      type2 = 0
      tmp = trigger['type']
      tmp = nil unless tmp.is_a?(Hash)

      case trigger['trigger_type']
        when TASK_TIME_TRIGGER_DAILY
          if tmp && tmp['days_interval']
            type1 = [tmp['days_interval'],0].pack('SS').unpack('L').first
          end
        when TASK_TIME_TRIGGER_WEEKLY
          if tmp && tmp['weeks_interval'] && tmp['days_of_week']
            type1 = [tmp['weeks_interval'],tmp['days_of_week']].pack('SS').unpack('L').first
          end
        when TASK_TIME_TRIGGER_MONTHLYDATE
          if tmp && tmp['months'] && tmp['days']
            type2 = [tmp['months'],0].pack('SS').unpack('L').first
            type1 = tmp['days']
          end
        when TASK_TIME_TRIGGER_MONTHLYDOW
          if tmp && tmp['weeks'] && tmp['days_of_week'] && tmp['months']
            type1 = [tmp['weeks'],tmp['days_of_week']].pack('SS').unpack('L').first
            type2 = [tmp['months'],0].pack('SS').unpack('L').first
          end
        when TASK_TIME_TRIGGER_ONCE
          # Do nothing. The Type member of the TASK_TRIGGER struct is ignored.
        else
          raise Error, 'Unknown trigger type'
      end

      pTrigger = [
        48,
        0,
        trigger['start_year'] || 0,
        trigger['start_month'] || 0,
        trigger['start_day'] || 0,
        trigger['end_year'] || 0,
        trigger['end_month'] || 0,
        trigger['end_day'] || 0,
        trigger['start_hour'] || 0,
        trigger['start_minute'] || 0,
        trigger['minutes_duration'] || 0,
        trigger['minutes_interval'] || 0,
        trigger['flags'] || 0,
        trigger['trigger_type'] || 0,
        type1,
        type2,
        0,
        trigger['random_minutes_interval'] || 0
      ].pack('S10L4LLSS')

      hr = setTrigger.call(pITaskTrigger, pTrigger)

      if hr != S_OK
        raise Error, get_last_error
      end

      release.call(pITaskTrigger)
    end

    # Returns the flags (integer) that modify the behavior of the work item. You
    # must OR the return value to determine the flags yourself.
    #
    def flags
      raise Error, 'null pointer' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 120

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 120)
      table = table.unpack('L*')

      getFlags = Win32::API::Function.new(table[29], 'PP', 'L')
      ptr = 0.chr * 4
      hr = getFlags.call(@pITask, ptr)

      if hr != S_OK
        raise Error, get_last_error
      end

      flags = ptr.unpack('L').first
    end

    # Sets an OR'd value of flags that modify the behavior of the work item.
    #
    def flags=(flags)
      raise Error, 'null pointer' if @pITS.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 116

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 116)
      table = table.unpack('L*')

      setFlags = Win32::API::Function.new(table[28], 'PL', 'L')
      hr = setFlags.call(@pITask, flags)

      if hr != S_OK
        raise Error, get_last_error
      end

      flags
    end

    # Returns the status of the currently active task. Possible values are
    # 'ready', 'running', 'not scheduled' or 'unknown'.
    #
    def status
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 68

      memcpy(lpVtbl,@pITask,4)
      memcpy(table,lpVtbl.unpack('L').first,68)
      table = table.unpack('L*')

      getStatus = Win32::API::Function.new(table[16], 'PP', 'L')
      ptr = 0.chr * 4
      hr = getStatus.call(@pITask, ptr)

      if hr != S_OK
        raise Error,get_last_error
      end

      st = ptr.unpack('L').first

      case st
        when 0x00041300 # SCHED_S_TASK_READY
           status = 'ready'
        when 0x00041301 # SCHED_S_TASK_RUNNING
           status = 'running'
        when 0x00041305 # SCHED_S_TASK_NOT_SCHEDULED
           status = 'not scheduled'
        else
           status = 'unknown'
      end

      status
    end

    # Returns the exit code from the last scheduled run.
    #
    def exit_code
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table = 0.chr * 72

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 72)
      table = table.unpack('L*')

      getExitCode = Win32::API::Function.new(table[17], 'PP', 'L')
      ptr = 0.chr * 4
      hr = getExitCode.call(@pITask, ptr)

      if hr > 0x80000000
        raise Error, get_last_error
      end

      ptr.unpack('L').first
    end

    # Returns the comment associated with the task, if any.
    #
    def comment
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 80

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 80)
      table = table.unpack('L*')

      getComment = Win32::API::Function.new(table[19], 'PP', 'L')
      ptr = 0.chr * 4
      hr = getComment.call(@pITask, ptr)

      if hr != S_OK
        raise Error,get_last_error
      end

      str = 0.chr * 256
      wcscpy(str, ptr.unpack('L').first)
      CoTaskMemFree(ptr.unpack('L').first)
      wide_to_multi(str)
    end

    # Sets the comment for the task.
    #
    def comment=(comment)
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless comment.is_a?(String)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 76

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 76)
      table = table.unpack('L*')

      setComment = Win32::API::Function.new(table[18], 'PP', 'L')
      comment_w = multi_to_wide(comment)
      hr = setComment.call(@pITask, comment_w)

      if hr != S_OK
        raise Error, get_last_error
      end

      comment
    end

    # Returns the name of the user who created the task.
    #
    def creator
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 88

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 88)
      table = table.unpack('L*')

      getCreator = Win32::API::Function.new(table[21], 'PP', 'L')
      ptr = 0.chr * 4
      hr = getCreator.call(@pITask, ptr)

      if hr != S_OK
        raise Error, get_last_error
      end

      str = 0.chr * 256
      wcscpy(str, ptr.unpack('L').first)
      CoTaskMemFree(ptr.unpack('L').first)
      wide_to_multi(str)
    end

    # Sets the creator for the task.
    #
    def creator=(creator)
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless creator.is_a?(String)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 84

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 84)
      table = table.unpack('L*')

      setCreator = Win32::API::Function.new(table[20], 'PP', 'L')
      creator_w = multi_to_wide(creator)
      hr = setCreator.call(@pITask, creator_w)

      if hr != S_OK
        raise Error, get_last_error
      end

      creator
    end

    # Returns a Time object that indicates the next time the task will run.
    #
    def next_run_time
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 40

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 40)
      table = table.unpack('L*')

      getNextRunTime = Win32::API::Function.new(table[9], 'PP', 'L')
      st = 0.chr * 16
      hr = getNextRunTime.call(@pITask, st)

      if hr != S_OK
        raise Error, get_last_error
      end

      a1,a2,_,a3,a4,a5,a6,a7 = st.unpack('S*')
      a7 *= 1000

      Time.local(a1,a2,a3,a4,a5,a6,a7)
    end

    # Returns a Time object indicating the most recent time the task ran or
    # nil if the task has never run.
    #
    def most_recent_run_time
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 64

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 64)
      table = table.unpack('L*')

      getMostRecentRunTime = Win32::API::Function.new(table[15], 'PP', 'L')
      st = 0.chr * 16
      hr = getMostRecentRunTime.call(@pITask, st)

      if hr == 0x00041303 # SCHED_S_TASK_HAS_NOT_RUN
        time = nil
      elsif hr == S_OK
        a1, a2, _, a3, a4, a5, a6, a7 = st.unpack('S*')
        a7 *= 1000
        time = Time.local(a1, a2, a3, a4, a5, a6, a7)
      else
        raise Error, get_last_error
      end

      time
    end

    # Returns the maximum length of time, in milliseconds, that the task
    # will run before terminating.
    #
    def max_run_time
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?

      lpVtbl = 0.chr * 4
      table  = 0.chr * 176

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 176)
      table = table.unpack('L*')

      getMaxRunTime = Win32::API::Function.new(table[43], 'PP', 'L')

      ptr = 0.chr * 4
      hr = getMaxRunTime.call(@pITask, ptr)

      if hr != S_OK
        raise Error, get_last_error
      end

      max_run_time = ptr.unpack('L').first
    end

    # Sets the maximum length of time, in milliseconds, that the task can run
    # before terminating. Returns the value you specified if successful.
    #
    def max_run_time=(max_run_time)
      raise Error, 'null pointer' if @pITask.nil?
      raise Error, 'No currently active task' if @pITask.nil?
      raise TypeError unless max_run_time.is_a?(Numeric)

      lpVtbl = 0.chr * 4
      table  = 0.chr * 172

      memcpy(lpVtbl, @pITask, 4)
      memcpy(table, lpVtbl.unpack('L').first, 172)
      table = table.unpack('L*')

      setMaxRunTime = Win32::API::Function.new(table[42], 'PL', 'L')
      hr = setMaxRunTime.call(@pITask, max_run_time)

      if hr != S_OK
        raise Error,get_last_error
      end

      max_run_time
    end

    # Returns whether or not the scheduled task exists.
    def exists?(job_name)
      bool = false
      Dir.foreach('C:/Windows/Tasks'){ |file|
        if File.basename(file, '.job') == job_name
          bool = true
          break
        end
      }
      bool
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
  end
end
