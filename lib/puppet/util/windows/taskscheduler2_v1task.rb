require 'puppet/util/windows/taskscheduler2'
require 'puppet/util/windows/taskscheduler' # Needed for the WIN32::ScheduledTask flag constants

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
  def initialize(work_item = nil, trigger = nil)
    @task = Puppet::Util::Windows::TaskScheduler2.new()

    if work_item
      if trigger
        raise TypeError unless trigger.is_a?(Hash)
        new_work_item(work_item, trigger)
      end
    end
  end

  def enum()
    array = []
    @task.enum_task_names(Puppet::Util::Windows::TaskScheduler2::ROOT_FOLDER,
        include_child_folders: false,
        include_compatibility: [Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_AT, Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V1]).each do |item|
      array << @task.get_task_name_from_task(item)
    end

    array
  end

  alias :tasks :enum

  def validate_task_name(task_name)
    # The Puppet provider and some other instances may pass a '.job' suffix as per the V1 API
    # This is not needed for the V2 API so we just remove it
    task_name = task_name.slice(0,task_name.length - 4) if task_name.end_with?('.job')

    task_name
  end

  def activate(task_name)
    raise TypeError unless task_name.is_a?(String)

    full_taskname = Puppet::Util::Windows::TaskScheduler2::ROOT_FOLDER + validate_task_name(task_name)

    result = @task.activate(full_taskname)
    return nil if result.nil?
    if @task.compatibility != Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_AT && @task.compatibility != Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V1
      @task.deactivate
      result = nil
    end

    result
  end

  def delete(task_name)
    
    @task.delete(validate_task_name(task_name))
  end

  def run()
    @task.run(nil)
  end

  def save(file = nil)
    raise NotImplementedError unless file.nil?

    @task.save
  end

  def terminate
    @task.terminate
  end

  def machine=(host)
    # The Puppet scheduledtask provider never calls this method.
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
    @task.set_principal(user, password)
  end

  def account_information
    principal = @task.principal

    principal.nil? ? nil : principal.UserId
  end

  def application_name
    action = default_action
    action.nil? ? nil : action.Path
  end

  def application_name=(app)
    action = default_action(true)
    action.Path = app

    app
  end

  def parameters
    action = default_action
    action.nil? ? nil : action.Arguments
  end

  def parameters=(param)
    action = default_action(true)
    action.Arguments = param

    param
  end

  def working_directory
    action = default_action
    action.nil? ? nil : action.WorkingDirectory
  end

  def working_directory=(dir)
    action = default_action
    action.WorkingDirectory = dir

    dir
  end

  def priority
    @task.priority
  end

  def priority=(value)
    raise TypeError unless value.is_a?(Numeric)

    @task.priority_value = value

    value
  end

  # Creates a new work item (scheduled job) with the given +trigger+. The
  # trigger variable is a hash of options that define when the scheduled
  # job should run.
  #
  def new_work_item(task_name, task_trigger)
    raise TypeError unless task_trigger.is_a?(Hash)

    task_name = Puppet::Util::Windows::TaskScheduler2::ROOT_FOLDER + validate_task_name(task_name)

    @task.new_task_defintion(task_name)

    @task.compatibility = Puppet::Util::Windows::TaskScheduler2::TASK_COMPATIBILITY_V1

    append_trigger(task_trigger)

    set_account_information('',nil)

    @task.definition
  end

  alias :new_task :new_work_item

  def trigger_count
    @task.trigger_count
  end

  def delete_trigger(v1index)
    # The older V1 API uses a starting index of zero, wherease the V2 API uses one.
    # Need to increment by one to maintain the same behavior
    @task.delete_trigger(v1index + 1)
  end

  # TODO Need to convert the API v2 style triggers into API V1 equivalent hash
  def trigger(v1index)
    # The older V1 API uses a starting index of zero, wherease the V2 API uses one.
    # Need to increment by one to maintain the same behavior
    populate_v1trigger(@task.trigger(v1index + 1))
  end

  # Sets the trigger for the currently active task.
  #
  # Note - This method name is a mis-nomer. It's actually appending a newly created trigger to the trigger collection.
  def trigger=(v1trigger)
    append_trigger(v1trigger)
  end
  def append_trigger(v1trigger)
    raise Error.new(_('No currently active task. ITask is NULL.')) if @task.definition.nil?
    raise TypeError unless v1trigger.is_a?(Hash)

    v2trigger = populate_v2trigger(v1trigger)
    @task.append_trigger(v2trigger)

    v1trigger
  end

  # Adds a trigger at the specified index.
  #
  # Note - This method name is a mis-nomer.  It's actually setting a trigger at the specified index
  def add_trigger(v1index, v1trigger)
    set_trigger(v1index, v1trigger)
  end
  def set_trigger(v1index, v1trigger)
    raise Error.new(_('No currently active task. ITask is NULL.')) if @task.definition.nil?
    raise TypeError unless v1trigger.is_a?(Hash)

    v2trigger = populate_v2trigger(v1trigger)
    # The older V1 API uses a starting index of zero, wherease the V2 API uses one.
    # Need to increment by one to maintain the same behavior
    @task.set_trigger(v1index + 1, v2trigger)

    v1trigger
  end

  def flags
    raise Error.new(_('No currently active task. ITask is NULL.')) if @task.definition.nil?

    flags = 0

    # Generate the V1 Flags integer from the task definition
    # flags list - https://msdn.microsoft.com/en-us/library/windows/desktop/aa381283%28v=vs.85%29.aspx
    # TODO Need to implement the rest of the flags
    flags = flags | Win32::TaskScheduler::DISABLED if !@task.definition.Settings.Enabled

    flags
  end

  def flags=(flags)
    raise Error.new(_('No currently active task. ITask is NULL.')) if @task.definition.nil?

    # TODO Need to implement the rest of the flags
    @task.definition.Settings.Enabled = !(flags & Win32::TaskScheduler::DISABLED)

    flags
  end

  def status
    @task.status
  end

  def exit_code
    @task.exit_code
  end

  def comment
    @task.comment
  end

  def comment=(comment)
    @task.comment = comment

    comment
  end

  def creator
    @task.creator
  end

  def creator=(creator)
    @task.creator = creator

    creator
  end

  def next_run_time
    @task.next_run_time
  end

  def most_recent_run_time
    @task.most_recent_run_time
  end

  def max_run_time
    @task.max_run_time_as_ms
  end

  # Sets the maximum length of time, in milliseconds, that the task can run
  # before terminating. Returns the value you specified if successful.
  #
  def max_run_time=(max_run_time)
    raise TypeError unless max_run_time.is_a?(Numeric)

    # Convert runtime into seconds

    max_run_time = max_run_time / (1000)
    mm, ss = max_run_time.divmod(60)
    hh, mm = mm.divmod(60)
    dd, hh = hh.divmod(24)

    @task.max_run_time = @task.hash_to_time_limit({
      :day => dd,
      :hour => hh,
      :minute => mm,
      :second => ss,
    })

    #raise Error.new(_('No currently active task. ITask is NULL.')) if @pITask.nil?
    #raise TypeError unless max_run_time.is_a?(Numeric)

    #@pITask.SetMaxRunTime(max_run_time)

    max_run_time
  end

  def exists?(job_name)
    # task name comparison is case insensitive
    tasks.any? { |name| name.casecmp(job_name) == 0 }
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

  def normalize_datetime(year, month, day, hour, minute)
    DateTime.new(year, month, day, hour, minute, 0).strftime('%FT%T')
  end

  # TODO Needs tests? probably not
  def default_action(create_if_missing = false)
    if @task.action_count < 1
      return nil unless create_if_missing
      # V1 tasks only support TASK_ACTION_EXEC
      action = @task.create_action(Puppet::Util::Windows::TaskScheduler2::TASK_ACTION_EXEC)
    else
      action = @task.action(1) # ActionsCollection is a 1 based array
    end

    # As this class is emulating the older V1 API we only support execution actions (not email etc.)
    return nil unless action.Type == Puppet::Util::Windows::TaskScheduler2::TASK_ACTION_EXEC

    action
  end

  def trigger_date_part_to_int(value, datepart)
    return 0 if value.nil?
    return 0 unless value.is_a?(String)
    return 0 if value.empty?
 
    DateTime.parse(value).strftime(datepart).to_i
  end

  def trigger_duration_to_minutes(value)
    return 0 if value.nil?
    return 0 unless value.is_a?(String)
    return 0 if value.empty?
 
    duration = @task.duration_hash_to_seconds(@task.time_limit_to_hash(value))

    duration / 60
   end
   
  def trigger_string_to_int(value)
    return 0 if value.nil?
    return value if value.is_a?(Integer)
    return 0 unless value.is_a?(String)
    return 0 if value.empty?

    value.to_i
  end

  # Convert a V2 compatible Trigger has into the older V1 trigger hash
  def populate_v1trigger(v2trigger)

    trigger_flags = 0
    trigger_flags = trigger_flags | Win32::TaskScheduler::TASK_TRIGGER_FLAG_HAS_END_DATE unless v2trigger['endboundary'].empty?
    # There is no corresponding setting for the V1 flag TASK_TRIGGER_FLAG_KILL_AT_DURATION_END
    trigger_flags = trigger_flags | Win32::TaskScheduler::TASK_TRIGGER_FLAG_DISABLED unless v2trigger['enabled']

    v1trigger = {
      'start_year'              => trigger_date_part_to_int(v2trigger['startboundary'], '%Y'),
      'start_month'             => trigger_date_part_to_int(v2trigger['startboundary'], '%m'),
      'start_day'               => trigger_date_part_to_int(v2trigger['startboundary'], '%d'),
      'end_year'                => trigger_date_part_to_int(v2trigger['endboundary'], '%Y'),
      'end_month'               => trigger_date_part_to_int(v2trigger['endboundary'], '%m'),
      'end_day'                 => trigger_date_part_to_int(v2trigger['endboundary'], '%d'),
      'start_hour'              => trigger_date_part_to_int(v2trigger['startboundary'], '%H'),
      'start_minute'            => trigger_date_part_to_int(v2trigger['startboundary'], '%M'),
      'minutes_duration'        => trigger_duration_to_minutes(v2trigger['repetition']['duration']),
      'minutes_interval'        => trigger_duration_to_minutes(v2trigger['repetition']['interval']),
      'flags'                   => trigger_flags,
      'random_minutes_interval' => trigger_string_to_int(v2trigger['randomdelay'])
    }

    case v2trigger['type']
      when Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_TIME
        v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_ONCE
        v1trigger['type'] = {}
      when Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_DAILY
        v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_DAILY
        v1trigger['type'] = {}
        v1trigger['type']['days_interval'] = trigger_string_to_int(v2trigger['daysinterval'])
      when Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_WEEKLY
        v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_WEEKLY
        v1trigger['type'] = {}
        v1trigger['type']['weeks_interval'] = trigger_string_to_int(v2trigger['weeksinterval'])
        v1trigger['type']['days_of_week'] = trigger_string_to_int(v2trigger['daysofweek'])
      when Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_MONTHLY
        v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_MONTHLYDATE
        v1trigger['type'] = {}
        v1trigger['type']['days'] = trigger_string_to_int(v2trigger['daysofmonth'])
        v1trigger['type']['months'] = trigger_string_to_int(v2trigger['monthsofyear'])
      when Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_MONTHLYDOW
        v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_MONTHLYDOW
        v1trigger['type'] = {}
        v1trigger['type']['weeks'] = trigger_string_to_int(v2trigger['weeksofmonth'])
        v1trigger['type']['days_of_week'] = trigger_string_to_int(v2trigger['daysofweek'])
        v1trigger['type']['months'] = trigger_string_to_int(v2trigger['monthsofyear'])
      else
        raise Error.new(_("Unknown trigger type %{type}") % { type: v2trigger['type'] })
    end

    v1trigger
  end

  # Convert the older V1 trigger hash into a V2 compatible Trigger hash
  def populate_v2trigger(v1trigger)
    v1trigger = transform_and_validate(v1trigger)

    # Default ITaskTrigger interface properties
    v2trigger = {
      'enabled' => true,
      'endboundary' => '',
      'executiontimelimit' => '',
      'repetition'=> {
        'interval' => '',
        'duration' => '',
        'stopatdurationend' => false,
      },
      'startboundary' => '',
    }

    v2trigger['repetition']['interval'] = "PT#{v1trigger['minutes_interval']}M" unless v1trigger['minutes_interval'].nil? || v1trigger['minutes_interval'].zero? 
    v2trigger['repetition']['duration'] = "PT#{v1trigger['minutes_duration']}M" unless v1trigger['minutes_duration'].nil? || v1trigger['minutes_duration'].zero? 
    v2trigger['startboundary'] = normalize_datetime(v1trigger['start_year'],
                                                    v1trigger['start_month'],
                                                    v1trigger['start_day'],
                                                    v1trigger['start_hour'],
                                                    v1trigger['start_minute']
    )

    tmp = v1trigger['type'].is_a?(Hash) ? v1trigger['type'] : nil

    case v1trigger['trigger_type']
      when :TASK_TIME_TRIGGER_DAILY
        v2trigger['type'] = Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_DAILY
        v2trigger['daysinterval'] = tmp['days_interval']
        # Static V2 settings which are not set by the Puppet scheduledtask provider
        v2trigger['randomdelay'] = ''

      when :TASK_TIME_TRIGGER_WEEKLY
        v2trigger['type'] = Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_WEEKLY
        v2trigger['daysofweek'] = tmp['days_of_week']
        v2trigger['weeksinterval'] = tmp['weeks_interval']
        # Static V2 settings which are not set by the Puppet scheduledtask provider
        v2trigger['runonlastweekofmonth'] = false
        v2trigger['randomdelay'] = ''

      when :TASK_TIME_TRIGGER_MONTHLYDATE
        v2trigger['type'] = Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_MONTHLY
        v2trigger['daysofmonth'] = tmp['days']
        v2trigger['monthsofyear'] = tmp['months']
        # Static V2 settings which are not set by the Puppet scheduledtask provider
        v2trigger['runonlastweekofmonth'] = false
        v2trigger['randomdelay'] = ''

      when :TASK_TIME_TRIGGER_MONTHLYDOW
        v2trigger['type'] = Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_MONTHLYDOW
        v2trigger['daysofweek'] = tmp['days_of_week']
        v2trigger['monthsofyear'] = tmp['months']
        v2trigger['weeksofmonth'] = tmp['weeks']
        # Static V2 settings which are not set by the Puppet scheduledtask provider
        v2trigger['runonlastweekofmonth'] = false
        v2trigger['randomdelay'] = ''

      when :TASK_TIME_TRIGGER_ONCE
        v2trigger['type'] = Puppet::Util::Windows::TaskScheduler2::TASK_TRIGGER_TIME
        # Static V2 settings which are not set by the Puppet scheduledtask provider
        v2trigger['randomdelay'] = ''
      else
        raise Error.new(_("Unknown V1 trigger type %{type}") % { type: v1trigger['trigger_type'] })
    end

    # Convert the V1 Trigger Flags into V2 API settings
    # There V1 flag TASK_TRIGGER_FLAG_HAS_END_DATE is already expressed in the endboundary setting
    # There is no corresponding setting for the V1 flag TASK_TRIGGER_FLAG_KILL_AT_DURATION_END
    raise Error.new(_('The TASK_TRIGGER_FLAG_KILL_AT_DURATION_END flag can not be used on Version 2 API triggers')) if (v1trigger['flags'] & ~Win32::TaskScheduler::TASK_TRIGGER_FLAG_KILL_AT_DURATION_END) != 0
    v2trigger['enabled'] = (v1trigger['flags'] & ~Win32::TaskScheduler::TASK_TRIGGER_FLAG_DISABLED).zero?

    v2trigger
  end
end
