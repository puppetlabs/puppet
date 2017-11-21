# This class is used to manage V1 compatible tasks using the Task Scheduler V2 API
# It is designed to be a binary compatible API to puppet/util/windows/taskscheduler.rb but
# will only surface the features used by the Puppet scheduledtask provider
#
class Puppet::Util::Windows::TaskScheduler2V1Task
  # The error class raised if any task scheduler specific calls fail.
  class Error < Puppet::Util::Windows::Error; end

  public
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
  end

  # Returns an array of scheduled task names.
  #
  def enum
    raise NotImplementedError
  end
  alias :tasks :enum

  # Activate the specified task.
  #
  def activate(task)
    raise NotImplementedError
  end

  # Delete the specified task name.
  #
  def delete(task)
    raise NotImplementedError
  end

  # Execute the current task.
  #
  def run
    raise NotImplementedError
  end

  # Saves the current task. Tasks must be saved before they can be activated.
  # The .job file itself is typically stored in the C:\WINDOWS\Tasks folder.
  #
  # If +file+ (an absolute path) is specified then the job is saved to that
  # file instead. A '.job' extension is recommended but not enforced.
  #
  def save(file = nil)
    raise NotImplementedError
  end

  # Terminate the current task.
  #
  def terminate
    raise NotImplementedError
  end

  # Set the host on which the various TaskScheduler methods will execute.
  #
  def machine=(host)
    raise NotImplementedError
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
    nil
  end

  # Returns the user associated with the task or nil if no user has yet
  # been associated with the task.
  #
  def account_information
    raise NotImplementedError
  end

  # Returns the name of the application associated with the task.
  #
  def application_name
    raise NotImplementedError
  end

  # Sets the application name associated with the task.
  #
  def application_name=(app)
    app
  end

  # Returns the command line parameters for the task.
  #
  def parameters
    raise NotImplementedError
  end

  # Sets the parameters for the task. These parameters are passed as command
  # line arguments to the application the task will run. To clear the command
  # line parameters set it to an empty string.
  #
  def parameters=(param)
    param
  end

  # Returns the working directory for the task.
  #
  def working_directory
    raise NotImplementedError
  end

  # Sets the working directory for the task.
  #
  def working_directory=(dir)
    dir
  end

  # Returns the task's priority level. Possible values are 'idle',
  # 'normal', 'high', 'realtime', 'below_normal', 'above_normal',
  # and 'unknown'.
  #
  def priority
    raise NotImplementedError
  end

  # Sets the priority of the task. The +priority+ should be a numeric
  # priority constant value.
  #
  def priority=(priority)
    raise NotImplementedError
  end

  # Creates a new work item (scheduled job) with the given +trigger+. The
  # trigger variable is a hash of options that define when the scheduled
  # job should run.
  #
  def new_work_item(task, trigger)
    raise NotImplementedError
  end
  alias :new_task :new_work_item

  # Returns the number of triggers associated with the active task.
  #
  def trigger_count
    0
  end

  # Deletes the trigger at the specified index.
  #
  def delete_trigger(index)
    raise NotImplementedError
  end

  # Returns a hash that describes the trigger at the given index for the
  # current task.
  #
  def trigger(index)
    raise NotImplementedError
  end

  # Sets the trigger for the currently active task.
  #
  def trigger=(trigger)
    trigger
  end

  # Adds a trigger at the specified index.
  #
  def add_trigger(index, trigger)
    raise NotImplementedError
  end

  # Returns the flags (integer) that modify the behavior of the work item. You
  # must OR the return value to determine the flags yourself.
  #
  def flags
    0
  end

  # Sets an OR'd value of flags that modify the behavior of the work item.
  #
  def flags=(flags)
    flags
  end

  # Returns the status of the currently active task. Possible values are
  # 'ready', 'running', 'not scheduled' or 'unknown'.
  #
  def status
    raise NotImplementedError
  end

  # Returns the exit code from the last scheduled run.
  #
  def exit_code
    raise NotImplementedError
  end

  # Returns the comment associated with the task, if any.
  #
  def comment
    raise NotImplementedError
  end

  # Sets the comment for the task.
  #
  def comment=(comment)
    raise NotImplementedError
  end

  # Returns the name of the user who created the task.
  #
  def creator
    raise NotImplementedError
  end

  # Sets the creator for the task.
  #
  def creator=(creator)
    raise NotImplementedError
  end

  # Returns a Time object that indicates the next time the task will run.
  #
  def next_run_time
    raise NotImplementedError
  end

  # Returns a Time object indicating the most recent time the task ran or
  # nil if the task has never run.
  #
  def most_recent_run_time
    raise NotImplementedError
  end

  # Returns the maximum length of time, in milliseconds, that the task
  # will run before terminating.
  #
  def max_run_time
    raise NotImplementedError
  end

  # Sets the maximum length of time, in milliseconds, that the task can run
  # before terminating. Returns the value you specified if successful.
  #
  def max_run_time=(max_run_time)
    raise NotImplementedError
  end

  # Returns whether or not the scheduled task exists.
  def exists?(job_name)
    raise NotImplementedError
  end
end
