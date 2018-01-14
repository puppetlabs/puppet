require 'puppet/util/windows'

# The TaskScheduler2 class encapsulates taskscheduler settings and behavior using the v2 API
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa383600(v=vs.85).aspx

# @api private
module Puppet::Util::Windows::TaskScheduler2
  # The error class raised if any task scheduler specific calls fail.
  # class Error < Puppet::Util::Windows::Error; end

  @@service_object = nil

  # The name of the root folder for tasks
  ROOT_FOLDER = '\\'

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

  def self.folder_path_from_task_path(task_path)
    path = task_path.rpartition('\\')[0]

    path.empty? ? ROOT_FOLDER : path
  end

  def self.task_name_from_task_path(task_path)
    task_path.rpartition('\\')[2]
  end

  # Returns an array of scheduled task names.
  # By default EVERYTHING is enumerated
  # option hash
  #    include_child_folders: recurses into child folders for tasks. Default true
  #    include_compatibility: Only include tasks which have any of the specified compatibility levels. Default empty array (everything is permitted)
  #
  def self.enum_task_names(folder_path = ROOT_FOLDER, options = {})
    raise TypeError unless folder_path.is_a?(String)

    options[:include_child_folders] = true if options[:include_child_folders].nil?
    options[:include_compatibility] = [] if options[:include_compatibility].nil?

    array = []

    task_folder = task_service.GetFolder(folder_path)
    task_folder.GetTasks(TASK_ENUM_HIDDEN).each do |task|
      included = true
      included = included && options[:include_compatibility].include?(task.Definition.Settings.Compatibility) unless options[:include_compatibility].empty?

      array << task.Path if included
    end
    return array unless options[:include_child_folders]

    task_folder.GetFolders(0).each do |child_folder|
      array += enum_task_names(child_folder.Path, options)
    end

    array
  end

  def self.task(task_path)
    raise TypeError unless task_path.is_a?(String)

    task_folder = task_service.GetFolder(folder_path_from_task_path(task_path))

    task_object = task_folder.GetTask(task_name_from_task_path(task_path))

    task_object
  end

  def self.definition(task_object = nil)
    definition = task_service.NewTask(0)
    definition.XmlText = task_object.XML unless task_object.nil?

    definition
  end

  # Creates or Updates an existing task with the supplied task definition
  # If task_object is a string then this is a new task and the supplied object is the new task's full path
  # Otherwise we expect a Win32OLE Task object to be passed through
  def self.save(task_object, definition, password = nil)
    task_path = task_object.is_a?(String) ? task_object : task_object.Path

    task_folder = task_service.GetFolder(folder_path_from_task_path(task_path))
    task_user = nil
    task_password = nil

    case definition.Principal.LogonType
      when TASK_LOGON_PASSWORD, TASK_LOGON_INTERACTIVE_TOKEN_OR_PASSWORD
        task_user = definition.Principal.UserId
        task_password = password
    end
    task_folder.RegisterTaskDefinition(task_name_from_task_path(task_path),
                                       definition, TASK_CREATE_OR_UPDATE, task_user, task_password,
                                       definition.Principal.LogonType)
  end

  # Delete the specified task name.
  #
  def self.delete(task_path)
    raise TypeError unless task_path.is_a?(String)
    task_folder = task_service.GetFolder(folder_path_from_task_path(task_path))

    result = task_folder.DeleteTask(task_name_from_task_path(task_path),0)

    result == Puppet::Util::Windows::COM::S_OK
  end

  # General Properties
  def self.principal(definition)
    definition.Principal
  end

  def self.set_principal(definition, user)
    if (user.nil? || user == "")
      # Setup for the local system account
      definition.Principal.UserId = 'SYSTEM'
      definition.Principal.LogonType = TASK_LOGON_SERVICE_ACCOUNT
      definition.Principal.RunLevel = TASK_RUNLEVEL_HIGHEST
      return true
    else
      definition.Principal.UserId = user
      definition.Principal.LogonType = TASK_LOGON_PASSWORD
      definition.Principal.RunLevel = TASK_RUNLEVEL_HIGHEST
      return true
    end
  end

  # Returns the compatibility level of the task.
  #
  def self.compatibility(definition)
    definition.Settings.Compatibility
  end

  # Sets the compatibility with the task.
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381846(v=vs.85).aspx
  #
  def self.set_compatibility(definition, value)
    definition.Settings.Compatibility = value
  end

  # Task Actions
  # Returns the number of actions associated with the active task.
  #
  def self.action_count(definition)
    definition.Actions.count
  end

  def self.action(definition, index)
    result = nil

    begin
      result = definition.Actions.Item(index)
    rescue WIN32OLERuntimeError => err
      # E_INVALIDARG 0x80070057 from # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378137%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
      if err.message =~ /80070057/m
        result = nil
      else
        raise
      end
    end

    result
  end

  def self.create_action(definition, action_type)
    definition.Actions.Create(action_type)
  end

  # Task Triggers
  def self.trigger_count(definition)
    definition.Triggers.count
  end

  # Returns a Win32OLE Trigger Object for the trigger at the given index for the
  # supplied definition.
  #
  # Returns nil if the index does not exist
  #
  # Note - This is a 1 based array (not zero)
  #
  def self.trigger(definition, index)
    result = nil

    begin
      result = definition.Triggers.Item(index)
    rescue WIN32OLERuntimeError => err
      # E_INVALIDARG 0x80070057 from # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378137%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
      if err.message =~ /80070057/m
        result = nil
      else
        raise
      end
    end

    result
  end

  def self.append_new_trigger(definition, trigger_type)
    definition.Triggers.create(trigger_type)
  end

  # Deletes the trigger at the specified index.
  #
  def self.delete_trigger(definition, index)
    definition.Triggers.Remove(index)

    index
  end

  # Helpers

  # From https://msdn.microsoft.com/en-us/library/windows/desktop/aa381850(v=vs.85).aspx
  # https://en.wikipedia.org/wiki/ISO_8601#Durations
  #
  # The format for this string is PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of months,
  # nD is the number of days, 'T' is the date/time separator, nH is the number of hours, nM is the number of minutes,
  # and nS is the number of seconds (for example, PT5M specifies 5 minutes and P1M4DT2H5M specifies one month,
  # four days, two hours, and five minutes)
  def self.duration_to_hash(duration)
    regex = /^P((?'year'\d+)Y)?((?'month'\d+)M)?((?'day'\d+)D)?(T((?'hour'\d+)H)?((?'minute'\d+)M)?((?'second'\d+)S)?)?$/

    matches = regex.match(duration)
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
  # https://en.wikipedia.org/wiki/ISO_8601#Durations
  # returns PT0S if there is nothing set.
  def self.hash_to_duration(hash)
    duration = 'P'
    duration += hash[:year].to_s + 'Y' unless hash[:year].nil? || hash[:year].zero?
    duration += hash[:month].to_s + 'M' unless hash[:month].nil? || hash[:month].zero?
    duration += hash[:day].to_s + 'D' unless hash[:day].nil? || hash[:day].zero?
    duration += 'T'
    duration += hash[:hour].to_s + 'H' unless hash[:hour].nil? || hash[:hour].zero?
    duration += hash[:minute].to_s + 'M' unless hash[:minute].nil? || hash[:minute].zero?
    duration += hash[:second].to_s + 'S' unless hash[:second].nil? || hash[:second].zero?

    duration == 'PT' ? 'PT0S' : duration
  end

  # Private methods
  def self.task_service
    if @@service_object.nil?
      @@service_object = WIN32OLE.new('Schedule.Service')
      @@service_object.connect()
    end
    @@service_object
  end
  private_class_method :task_service
end
