require 'puppet/util/windows/com'

# The TaskScheduler2 class encapsulates taskscheduler settings and behavior using the v2 API
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa383600(v=vs.85).aspx

# @api private
class Puppet::Util::Windows::TaskScheduler2
  # The error class raised if any task scheduler specific calls fail.
  class Error < Puppet::Util::Windows::Error; end

  # The name of the root folder for tasks
  ROOT_FOLDER = '\\'
  
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378137(v=vs.85).aspx
  S_OK = 0

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383558(v=vs.85).aspx
  TASK_ENUM_HIDDEN  = 0x1

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380596(v=vs.85).aspx
  TASK_ACTION_EXEC = 0
  TASK_ACTION_COM_HANDLER = 5
  TASK_ACTION_SEND_EMAIL = 6
  TASK_ACTION_SHOW_MESSAGE = 7

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383557(v=vs.85).aspx
  # Undocumented values
  # Win7/2008 R2                       = 3
  # Win8/Server 2012 R2 or Server 2016 = 4
  # Windows 10                         = 6
  TASK_COMPATIBILITY_AT = 0
  TASK_COMPATIBILITY_V1 = 1
  TASK_COMPATIBILITY_V2 = 2

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383617(v=vs.85).aspx
  TASK_STATE_UNKNOWN  = 0
  TASK_STATE_DISABLED = 1
  TASK_STATE_QUEUED   = 2
  TASK_STATE_READY    = 3
  TASK_STATE_RUNNING  = 4

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383915%28v=vs.85%29.aspx
  TASK_TRIGGER_EVENT                 = 0
  TASK_TRIGGER_TIME                  = 1
  TASK_TRIGGER_DAILY                 = 2
  TASK_TRIGGER_WEEKLY                = 3
  TASK_TRIGGER_MONTHLY               = 4
  TASK_TRIGGER_MONTHLYDOW            = 5
  TASK_TRIGGER_IDLE                  = 6
  TASK_TRIGGER_REGISTRATION          = 7
  TASK_TRIGGER_BOOT                  = 8
  TASK_TRIGGER_LOGON                 = 9
  TASK_TRIGGER_SESSION_STATE_CHANGE  = 11

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382538%28v=vs.85%29.aspx
  TASK_VALIDATE_ONLY                 = 0x1
  TASK_CREATE                        = 0x2
  TASK_UPDATE                        = 0x4
  TASK_CREATE_OR_UPDATE              = 0x6
  TASK_DISABLE                       = 0x8
  TASK_DONT_ADD_PRINCIPAL_ACE        = 0x10
  TASK_IGNORE_REGISTRATION_TRIGGERS  = 0x20

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383566(v=vs.85).aspx
  TASK_LOGON_NONE                           = 0
  TASK_LOGON_PASSWORD                       = 1
  TASK_LOGON_S4U                            = 2
  TASK_LOGON_INTERACTIVE_TOKEN              = 3
  TASK_LOGON_GROUP                          = 4
  TASK_LOGON_SERVICE_ACCOUNT                = 5
  TASK_LOGON_INTERACTIVE_TOKEN_OR_PASSWORD  = 6

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380747(v=vs.85).aspx
  TASK_RUNLEVEL_LUA     = 0
  TASK_RUNLEVEL_HIGHEST = 1

  def initialize(task_name = nil)
    @task_service = nil
    @pITask = nil

    @task_service = WIN32OLE.new('Schedule.Service')
    @task_service.connect()

    activate(task_name) unless task_name.nil?
  end

    # TODO SHOULD BE  tested
    def get_folder_path_from_task(task_name)
      path = task_name.rpartition('\\')[0]
  
      path.empty? ? ROOT_FOLDER : path
    end
  
    # TODO SHOULD BE  tested
    def get_task_name_from_task(task_name)
      task_name.rpartition('\\')[2]
    end
    
  # Returns an array of scheduled task names.
  # By default EVERYTHING is enumerated
  # option hash
  #    include_child_folders: recurses into child folders for tasks. Default true
  #    include_compatibility: Only include tasks which have any of the specified compatibility levels. Default empty array (everything is permitted)
  #
  def enum_task_names(folder_path = ROOT_FOLDER, options = {})
    raise Error.new(_('No current task scheduler. Schedule.Service is NULL.')) if @task_service.nil?
    raise TypeError unless folder_path.is_a?(String)

    options[:include_child_folders] = true if options[:include_child_folders].nil?
    options[:include_compatibility] = [] if options[:include_compatibility].nil?

    array = []

    task_folder = @task_service.GetFolder(folder_path)

    task_folder.GetTasks(TASK_ENUM_HIDDEN).each do |task|
      included = true

      included = included && options[:include_compatibility].include?(task.Definition.Settings.Compatibility) unless options[:include_compatibility].empty?

      array << task.Path if included
    end
    return array unless options[:include_child_folders]

    task_folder.GetFolders(0).each do |child_folder|
      array = array + enum_task_names(child_folder.Path, options)
    end

    array
  end

  def activate(task)
    raise Error.new(_('No current task scheduler. Schedule.Service is NULL.')) if @task_service.nil?
    raise TypeError unless task.is_a?(String)

    task_folder = @task_service.GetFolder(get_folder_path_from_task(task))

    begin
      @pITask = task_folder.GetTask(get_task_name_from_task(task))
    rescue WIN32OLERuntimeError => e
      @pITask = nil
      # TODO win32ole errors are horrible.  Assume the task doesn't exist
    end
    @pITaskDefinition = nil
    
    @pITask
  end

  def deactivate()
    @pITask = nil
    @pITaskDefinition = nil
  end

  def definition()
    if @pITaskDefinition.nil? && !@pITask.nil?
      # Create a new editable Task Defintion based off of the currently activated task
      @pITaskDefinition = @task_service.NewTask(0)
      @pITaskDefinition.XmlText = @pITask.XML
    end

    @pITaskDefinition
  end

  # Delete the specified task name.
  #
  def delete(task)
    raise Error.new(_('No current task scheduler. Schedule.Service is NULL.')) if @task_service.nil?
    raise TypeError unless task.is_a?(String)

    task_folder = @task_service.GetFolder(get_folder_path_from_task(task))

    result = -1
    begin
      result = task_folder.DeleteTask(get_task_name_from_task(task),0)
    rescue WIN32OLERuntimeError => e
      # TODO win32ole errors are horrible.  Assume the task doesn't exist so deletion is successful
      return true
    end

    result == Puppet::Util::Windows::COM::S_OK
  end

  # Execute the current task.
  #
  def run(arguments = nil)
    raise Error.new(_('No currently active task. ITask is NULL.')) if @pITask.nil?

    @pITask.Run(arguments)
  end

  # Saves the current task. Tasks must be saved before they can be activated.
  #
  def save()
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    task_path = @pITask.nil? ? @task_defn_path : @pITask.Path

    task_folder = @task_service.GetFolder(get_folder_path_from_task(task_path))

    task_folder.RegisterTaskDefinition(get_task_name_from_task(task_path), 
                                       definition, TASK_CREATE_OR_UPDATE, nil, nil,
                                       definition.Principal.LogonType)
  end

  # Terminate the current task.
  #
  def terminate
    raise Error.new(_('No currently active task. ITask is NULL.')) if @pITask.nil?

    @pITask.Stop(0)
  end

  # TODO  Need to use the password
  def set_principal(user, password)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    if (user.nil? || user == "") && (password.nil? || password == "")
      # Setup for the local system account
      definition.Principal.UserId = 'SYSTEM'
      definition.Principal.LogonType = TASK_LOGON_SERVICE_ACCOUNT
      definition.Principal.RunLevel = TASK_RUNLEVEL_HIGHEST
      return true
    else
      # TODO!!!
      raise NotImplementedError
    end
  end

  # Returns the user associated with the task or nil if no user has yet
  # been associated with the task.
  def principal
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    definition.Principal
  end

  # Returns the compatibility level of the task.
  #
  def compatibility
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    definition.Settings.Compatibility
  end

  # Sets the compatibility with the task.
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381846(v=vs.85).aspx
  #
  def compatibility=(value)
    # TODO Do we need warnings about this?  could be dangerous?
    definition.Settings.Compatibility = value
  end

  # Returns the task's priority level. Possible values are 'idle',
  # 'normal', 'high', 'realtime', 'below_normal', 'above_normal',
  # and 'unknown'.
  # Note - This is an approximation due to how the priority class and thread priority
  # levels differ
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383070(v=vs.85).aspx
  #
  def priority
    case priority_value
    when 0
      'realtime'
    when 1
      'high'
    when 2,3
      'above_normal'
    when 4,5,6
      'normal'
    when 7,8
      'below_normal'
    when 9,10
      'idle'
    else
      'unknown'
    end
  end

  # Returns the task's priority level as an integer
  #
  def priority_value
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?
    
    definition.Settings.Priority
  end

  # Sets the priority of the task. The +priority+ should be a numeric
  # priority constant value, from 0 to 10 inclusive
  #
  def priority_value=(value)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?
    raise TypeError unless value.is_a?(Numeric)
    raise TypeError if value < 0
    raise TypeError if value > 10

    definition.Settings.Priority = value

    value
  end

  def new_task_defintion(task_name)
    raise Error.new(_("task '%{task}' already exists") % { task: task_name }) if exists?(task_name)

    @pITaskDefinition = @task_service.NewTask(0)
    @task_defn_path = task_name
    @pITask = nil

    true
  end

  # Returns the number of actions associated with the active task.
  #
  def action_count
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    definition.Actions.count
  end

  def action(index)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    action = nil

    begin
      action = definition.Actions.Item(index)
    rescue WIN32OLERuntimeError => err
      # E_INVALIDARG 0x80070057 from # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378137%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
      if err.message =~ /80070057/m
        action = nil
      else
        raise
      end
    end
    
    action
  end

  def create_action(action_type)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    definition.Actions.Create(action_type)
  end

  # Returns the number of triggers associated with the active task.
  #
  def trigger_count
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    definition.Triggers.count
  end

  # Deletes the trigger at the specified index.
  #
  def delete_trigger(index)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    definition.Triggers.Remove(index)

    index
  end

  # Returns a hash that describes the trigger at the given index for the
  # current task.
  #
  # Returns nil if the index does not exist
  #
  # Note - This is a 1 based array (not zero)
  #
  def trigger(index)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?
    
    trigger = nil

    begin
      trigger = populate_hash_from_trigger(definition.Triggers.Item(index))
    rescue WIN32OLERuntimeError => err
      # E_INVALIDARG 0x80070057 from # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378137%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
      if err.message =~ /80070057/m
        trigger = nil
      else
        raise
      end
    end
    
    trigger
  end

  def append_trigger(trigger_hash)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?
    
    obj = definition.Triggers.create(trigger_hash['type'])

    set_properties_from_hash(obj, trigger_hash)

    obj
  end

  def set_trigger(index, trigger_hash)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?
    
    obj = definition.Triggers.Item(index)
    
    set_properties_from_hash(obj, trigger_hash)

    obj
  end

  # Returns the status of the currently active task. Possible values are
  # 'ready', 'running', 'queued', 'disabled' or 'unknown'.
  #
  def status
    raise Error.new(_('No currently active task. ITask is NULL.')) if @pITask.nil?

    case @pITask.State
    when TASK_STATE_READY
      status = 'ready'
    when TASK_STATE_RUNNING
      status = 'running'
    when TASK_STATE_QUEUED
      status = 'queued'
    when TASK_STATE_DISABLED
      status = 'disabled'
    else
      status = 'unknown'
    end

    status
  end

  # Returns the exit code from the last scheduled run.
  #
  def exit_code
    raise Error.new(_('No currently active task. ITask is NULL.')) if @pITask.nil?

    # Note Exit Code 267011 is generated when the task has never been run
    status = @pITask.LastTaskResult

    status
  end

  # Returns the comment associated with the task, if any.
  #
  def comment
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    definition.RegistrationInfo.Description
  end

  # Sets the comment for the task.
  #
  def comment=(comment)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?
    
    definition.RegistrationInfo.Description = comment

    comment
  end

  # Returns the name of the user who created the task.
  #
  def creator
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?
    
    definition.RegistrationInfo.Author
  end

  # Sets the creator for the task.
  #
  def creator=(creator)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?
    
    definition.RegistrationInfo.Author = creator

    creator
  end

  # Returns a Time object that indicates the next time the task will run.
  # nil if the task has no scheduled time
  #
  def next_run_time
    raise Error.new(_('No currently active task. ITask is NULL.')) if @pITask.nil?

    time = @pITask.NextRunTime

    # The API will still return a time WAAAY in the past if there is no schedule.
    # As this is looking forward, if the next execution is 'scheduled' in the 1900s assume
    # this task is not actually scheduled at all
    time = nil if time.year < 2000

    time
  end

  # Returns a Time object indicating the most recent time the task ran or
  # nil if the task has never run.
  #
  def most_recent_run_time
    raise Error.new(_('No currently active task. ITask is NULL.')) if @pITask.nil?

    time = @pITask.LastRunTime
    
    # The API will still return a time WAAAY in the past if the task has not run.
    # If the last execution is in the 1900s assume this task has not run previosuly
    time.year < 2000 ? nil : time
  end

  def xml_definition
    raise Error.new(_('No currently active task. ITask is NULL.')) if @pITask.nil?

    @pITask.XML
  end

  # From https://msdn.microsoft.com/en-us/library/windows/desktop/aa381850(v=vs.85).aspx
  #
  # The format for this string is PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of months,
  # nD is the number of days, 'T' is the date/time separator, nH is the number of hours, nM is the number of minutes,
  # and nS is the number of seconds (for example, PT5M specifies 5 minutes and P1M4DT2H5M specifies one month,
  # four days, two hours, and five minutes)
  def time_limit_to_hash(time_limit)
    regex = /^P((?'year'\d+)Y)?((?'month'\d+)M)?((?'day'\d+)D)?T((?'hour'\d+)H)?((?'minute'\d+)M)?((?'second'\d+)S)?$/

    matches = regex.match(time_limit)
    return nil if matches.nil?

    {
      :year => matches['year'],
      :month => matches['month'],
      :day => matches['day'],
      :minute => matches['minute'],
      :hour => matches['hour'],
      :second => matches['second'],
    }
  end

  # Converts a hash table describing year, month, day etc. into a timelimit string as per
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381850(v=vs.85).aspx
  # returns PT0S if there is nothing set.
  def hash_to_time_limit(hash)
    limit = 'P'
    limit = limit + hash[:year].to_s + 'Y' unless hash[:year].nil? || hash[:year].zero?
    limit = limit + hash[:month].to_s + 'M' unless hash[:month].nil? || hash[:month].zero?
    limit = limit + hash[:day].to_s + 'D' unless hash[:day].nil? || hash[:day].zero?
    limit = limit + 'T'
    limit = limit + hash[:hour].to_s + 'H' unless hash[:hour].nil? || hash[:hour].zero?
    limit = limit + hash[:minute].to_s + 'M' unless hash[:minute].nil? || hash[:minute].zero?
    limit = limit + hash[:second].to_s + 'S' unless hash[:second].nil? || hash[:second].zero?

    limit == 'PT' ? 'PT0S' : limit
  end

  def duration_hash_to_seconds(value)
    time = 0
    # Note - the Year and Month calculations are approximate
    time = time + value[:year].to_i   * (365.2422 * 24 * 60**2).to_i unless value[:year].nil?
    time = time + value[:month].to_i  * (365.2422 * 2 * 60**2).to_i  unless value[:month].nil?
    time = time + value[:day].to_i    * 24 * 60**2                   unless value[:day].nil?
    time = time + value[:hour].to_i   * 60**2                        unless value[:hour].nil?
    time = time + value[:minute].to_i * 60                           unless value[:minute].nil?
    time = time + value[:second].to_i                                unless value[:second].nil?

    time
  end

  # Returns the maximum length of time, in milliseconds, that the task
  # will run before terminating.
  #
  def max_run_time_as_ms
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?

    # A value of PT0S will enable the task to run indefinitely.
    max_time = time_limit_to_hash(definition.Settings.ExecutionTimeLimit)

    max_time.nil? ? nil : duration_hash_to_seconds(max_time) * 1000
  end

  # Sets the maximum length of time, in milliseconds, that the task can run
  # before terminating. Returns the value you specified if successful.
  #
  def max_run_time=(max_run_time)
    raise Error.new(_('No currently active task. ITask is NULL.')) if definition.nil?
    
    definition.Settings.ExecutionTimeLimit = max_run_time

    max_run_time
  end

  # Returns whether or not the scheduled task exists.
  def exists?(job_name)
    # task name comparison is case insensitive
    enum_task_names.any? { |name| name.casecmp(job_name) == 0 }
  end

  private

  # Recursively converts a WIN32OLE Object in to a hash.  This method
  # only outputs the Get Methods for an Object that has no parameters on the methods
  # i.e. they are Object properties
  #
  def win32ole_to_hash(win32_obj)
    hash = {}

    win32_obj.ole_get_methods.each do |method|
      # Only interested in get methods with no params i.e. object properties
      if method.params.count == 0
        value = nil
        begin
          value = win32_obj.invoke(method.name)
        rescue WIN32OLERuntimeError => err
          # E_NOTIMPL 0x80004001 from # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378137(v=vs.85).aspx
          if err.message =~ /80004001/m
            # Somehow the interface has the OLE Method, but the underlying object does not implement the method.  In this case
            # just return nil and swallow the error
            value = nil
          else
            raise
          end
        end
        if value.is_a?(WIN32OLE)
          # Recurse into the object tree
          hash[method.name.downcase] = win32ole_to_hash(value)
        else
          hash[method.name.downcase] = value
        end
      end
    end

    hash
  end

  # Recursively sets properties on a WIN32OLE Object from a hash.  This method
  # only set the Put Methods for an Object
  def set_properties_from_hash(ole_obj, prop_hash)
    method_list = ole_obj.ole_put_methods.map { |method| method.name.downcase }

    prop_hash.each do |k,v|
      if v.is_a?(Hash)
        set_properties_from_hash ole_obj.invoke(k), v
      else
        new_val = v
        # Ruby 2.3.1 crashes when setting an empty string e.g. '', instead use nil
        new_val = nil if v.is_a?(String) && v.empty?
        ole_obj.setproperty(k,new_val) if method_list.include?(k.downcase)
      end
    end
  end

  def populate_hash_from_trigger(task_trigger)
    return nil if task_trigger.nil?

    hash = win32ole_to_hash(task_trigger)

    hash['type_name'] = task_trigger.ole_type.name

    hash
  end
end
