require 'puppet/util'

Puppet::Type.newtype(:scheduled_task) do
  include Puppet::Util

  @doc = "Installs and manages Windows Scheduled Tasks.  All fields
    except the name, command, and start_time are optional; specifying
    no repetition parameters will result in a task that runs once on
    the start date.

    Examples:

      # Create a task that will fire on August 31st, 2011 at 8am in
      # the system's time-zone.
      scheduled_task { 'One-shot task':
        ensure    => present,
        enabled   => true,
        command   => 'C:\path\to\command.exe',
        arguments => '/flags /to /pass',
        trigger   => {
          schedule   => once,
          start_date => '2011-08-31', # Defaults to 'today'
          start_time => '08:00',      # Must be specified
        }
      }

      # Create a task that will fire every other day at 8am in the
      # system's time-zone, starting August 31st, 2011.
      scheduled_task { 'Daily task':
        ensure    => present,
        enabled   => true,
        command   => 'C:\path\to\command.exe',
        arguments => '/flags /to /pass',
        trigger   => {
          schedule   => daily,
          every      => 2             # Defaults to 1
          start_date => '2011-08-31', # Defaults to 'today'
          start_time => '08:00',      # Must be specified
        }
      }

      # Create a task that will fire at 8am Monday every third week,
      # starting after August 31st, 2011.
      scheduled_task { 'Weekly task':
        ensure    => present,
        enabled   => true,
        command   => 'C:\path\to\command.exe',
        arguments => '/flags /to /pass',
        trigger   => {
          schedule    => weekly,
          every       => 3,           # Defaults to 1
          start_date  => '2011-08-31' # Defaults to 'today'
          start_time  => '08:00',     # Must be specified
          day_of_week => [mon],       # Defaults to all
        }
      }

      # Create a task that will fire at 8am on the 1st, 15th, and last
      # day of the month in January, March, May, July, September, and
      # November starting August 31st, 2011.
      scheduled_task { 'Monthly date task':
        ensure    => present,
        enabled   => true,
        command   => 'C:\path\to\command.exe',
        arguments => '/flags /to /pass',
        trigger   => {
          schedule   => monthly,
          start_date => '2011-08-31',   # Defaults to 'today'
          start_time => '08:00',        # Must be specified
          months     => [1,3,5,7,9,11], # Defaults to all
          on         => [1, 15, last],  # Must be specified
        }
      }

      # Create a task that will fire at 8am on the first Monday of the
      # month for January, March, and May, after August 31st, 2011.
      scheduled_task { 'Monthly day of week task':
        enabled   => true,
        ensure    => present,
        command   => 'C:\path\to\command.exe',
        arguments => '/flags /to /pass',
        trigger   => {
          schedule         => monthly,
          start_date       => '2011-08-31', # Defaults to 'today'
          start_time       => '08:00',      # Must be specified
          months           => [1,3,5],      # Defaults to all
          which_occurrence => first,        # Must be specified
          day_of_week      => [mon],        # Must be specified
        }
      }"

  ensurable

  newproperty(:enabled) do
    desc "Whether the triggers for this task are enabled.  This only
      supports enabling or disabling all of the triggers for a task,
      not enabling or disabling them on an individual basis."

    newvalue(:true,  :event => :task_enabled)
    newvalue(:false, :event => :task_disabled)

    defaultto(:true)
  end

  newparam(:name) do
    desc "The name assigned to the scheduled task.  This will uniquely
      identify the task on the system."

    isnamevar
  end

  newproperty(:command) do
    desc "The full path to the application to be run, without any
      arguments."

    validate do |value|
      raise Puppet::Error.new('Must be specified using an absolute path.') unless absolute_path?(value)
    end
  end

  newproperty(:working_dir) do
    desc "The full path of the directory in which to start the
      command"

    validate do |value|
      raise Puppet::Error.new('Must be specified using an absolute path.') unless absolute_path?(value)
    end
  end

  newproperty(:arguments, :array_matching => :all) do
    desc "The optional arguments to pass to the command."
  end

  newproperty(:user) do
    desc "The user to run the scheduled task as.  Please note that not
      all security configurations will allow running a scheduled task
      as 'SYSTEM', and saving the scheduled task under these
      conditions will fail with a reported error of 'The operation
      completed successfully'.  It is recommended that you either
      choose another user to run the scheduled task, or alter the
      security policy to allow v1 scheduled tasks to run as the
      'SYSTEM' account.  Defaults to 'SYSTEM'."

    defaultto :system

    def insync?(current)
      provider.user_insync?(current, @should)
    end
  end

  newparam(:password) do
    desc "The password for the user specified in the 'user' property.
      This is only used if specifying a user other than 'SYSTEM'.
      Since there is no way to retrieve the password used to set the
      account information for a task, this parameter will not be used
      to determine if a scheduled task is in sync or not."
  end

  newproperty(:trigger, :array_matching => :all) do
    desc "This is a hash defining the properties of the trigger used
      to fire the scheduled task.  The one key that is always required
      is 'schedule', which can be one of 'daily', 'weekly', or
      'monthly'.  The other valid & required keys depend on the value
      of schedule.

      When schedule is 'daily', you can specify a value for 'every'
      which specifies that the task will trigger every N days.  If
      'every' is not specified, it defaults to 1 (running every day).

      When schedule is 'weekly', you can specify values for 'every',
      and 'day_of_week'.  'every' has similar behavior as when
      specified for 'daily', though it repeats every N weeks, instead
      of every N days.  'day_of_week' is used to specify on which days
      of the week the task should be run.  This can be specified as an
      array where the possible values are 'mon', 'tues', 'wed',
      'thurs', 'fri', 'sat', and 'sun', or as the string 'all'.  The
      default is 'all'.

      When schedule is 'monthly', the syntax depends on whether you
      wish to specify the trigger using absolute, or relative dates.
      In either case, you can specify which months this trigger
      applies to using 'months', and specifying an array of integer
      months.  'months' defaults to all months.

      When specifying a monthly schedule with absolute dates, 'on'
      must be provided as an array of days (1-31, or the special value
      'last' which will always be the last day of the month).

      When specifying a monthly schedule with relative dates,
      'which_occurrence', and 'day_of_week' must be specified.  The
      possible values for 'which_occurrence' are 'first', 'second',
      'third', 'fourth', 'fifth', and 'last'.  'day_of_week' is an
      array where the possible values are 'mon', 'tues', 'wed',
      'thurs', 'fri', 'sat', and 'sun'.  These combine to be able to
      specify things like: The task should run on the first Monday of
      the specified month(s)."

    validate do |value|
      provider.validate_trigger(value)
    end

    def insync?(current)
      provider.trigger_insync?(current, @should)
    end

    def should_to_s(new_value=@should)
      self.class.format_value_for_display(new_value)
    end

    def is_to_s(current_value=@is)
      self.class.format_value_for_display(current_value)
    end
  end

  validate do
    return true if self[:ensure] == :absent

    if self[:arguments] and !(self[:arguments].is_a?(Array) and self[:arguments].length == 1)
      self.fail('Parameter arguments failed: Must be specified as a single string')
    end
  end
end
