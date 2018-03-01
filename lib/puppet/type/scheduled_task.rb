require 'puppet/util'

Puppet::Type.newtype(:scheduled_task) do
  include Puppet::Util

  @doc = "Installs and manages Windows Scheduled Tasks.  All attributes
    except `name`, `command`, and `trigger` are optional; see the description
    of the `trigger` attribute for details on setting schedules."

  ensurable

  newproperty(:enabled) do
    desc "Whether the triggers for this task should be enabled. This attribute
      affects every trigger for the task; triggers cannot be enabled or
      disabled individually."

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
    desc "The full path to the application to run, without any arguments."

    validate do |value|
      raise Puppet::Error.new(_('Must be specified using an absolute path.')) unless absolute_path?(value)
    end
    munge do |value|
      # windows converts slashes to backslashes, so the *is* value
      # has backslashes. Do the same for the *should* value, so that
      # we are slash-insensitive. See #13009
      File.expand_path(value).gsub(/\//, '\\')
    end
  end

  newproperty(:working_dir) do
    desc "The full path of the directory in which to start the command."

    validate do |value|
      raise Puppet::Error.new(_('Must be specified using an absolute path.')) unless absolute_path?(value)
    end
  end

  newproperty(:arguments) do
    desc "Any arguments or flags that should be passed to the command. Multiple arguments
      should be specified as a space-separated string."
  end

  newproperty(:user) do
    desc "The user to run the scheduled task as.  Please note that not
      all security configurations will allow running a scheduled task
      as 'SYSTEM', and saving the scheduled task under these
      conditions will fail with a reported error of 'The operation
      completed successfully'.  It is recommended that you either
      choose another user to run the scheduled task, or alter the
      security policy to allow v1 scheduled tasks to run as the
      'SYSTEM' account.  Defaults to 'SYSTEM'.

      Please also note that Puppet must be running as a privileged user
      in order to manage `scheduled_task` resources. Running as an
      unprivileged user will result in 'access denied' errors."

    defaultto :system

    def insync?(current)
      provider.user_insync?(current, @should)
    end
  end

  newparam(:password) do
    desc "The password for the user specified in the 'user' attribute.
      This is only used if specifying a user other than 'SYSTEM'.
      Since there is no way to retrieve the password used to set the
      account information for a task, this parameter will not be used
      to determine if a scheduled task is in sync or not."
  end

  newproperty(:trigger, :array_matching => :all) do
    desc <<-'EOT'
      One or more triggers defining when the task should run. A single trigger is
      represented as a hash, and multiple triggers can be specified with an array of
      hashes.

      A trigger can contain the following keys:

      * For all triggers:
          * `schedule` **(Required)** --- What kind of trigger this is.
            Valid values are `daily`, `weekly`, `monthly`, or `once`. Each kind
            of trigger is configured with a different set of keys; see the
            sections below. (`once` triggers only need a start time/date.)
          * `start_time` **(Required)** --- The time of day when the trigger should
            first become active. Several time formats will work, but we
            suggest 24-hour time formatted as HH:MM.
          * `start_date` ---  The date when the trigger should first become active.
            Defaults to the current date. You should format dates as YYYY-MM-DD,
            although other date formats may work. (Under the hood, this uses `Date.parse`.)
          * `minutes_interval` --- The repeat interval in minutes.
          * `minutes_duration` --- The duration in minutes, needs to be greater than the
            minutes_interval.
      * For `daily` triggers:
          * `every` --- How often the task should run, as a number of days. Defaults
            to 1. ("2" means every other day, "3" means every three days, and so on)
      * For `weekly` triggers:
          * `every` --- How often the task should run, as a number of weeks. Defaults
            to 1. ("2" means every other week, "3" means every three weeks, and so on)
          * `day_of_week` --- Which days of the week the task should run, as an array.
            Defaults to all days. Each day must be one of `mon`, `tues`,
            `wed`, `thurs`, `fri`, `sat`, `sun`, or `all`.
      * For `monthly` (by date) triggers:
          * `months` --- Which months the task should run, as an array. Defaults to
            all months. Each month must be an integer between 1 and 12.
          * `on` **(Required)** --- Which days of the month the task should run,
            as an array. Each day must be an integer between 1 and 31.
      * For `monthly` (by weekday) triggers:
          * `months` --- Which months the task should run, as an array. Defaults to
            all months. Each month must be an integer between 1 and 12.
          * `day_of_week` **(Required)** --- Which day of the week the task should
            run, as an array with only one element. Each day must be one of `mon`,
            `tues`, `wed`, `thurs`, `fri`, `sat`, `sun`, or `all`.
          * `which_occurrence` **(Required)** --- The occurrence of the chosen weekday
            when the task should run. Must be one of `first`, `second`, `third`,
            `fourth`, or `fifth`.


      Examples:

          # Run at 8am on the 1st and 15th days of the month in January, March,
          # May, July, September, and November, starting after August 31st, 2011.
          trigger => {
            schedule   => monthly,
            start_date => '2011-08-31',   # Defaults to current date
            start_time => '08:00',        # Must be specified
            months     => [1,3,5,7,9,11], # Defaults to all
            on         => [1, 15],        # Must be specified
          }

          # Run at 8am on the first Monday of the month for January, March, and May,
          # starting after August 31st, 2011.
          trigger => {
            schedule         => monthly,
            start_date       => '2011-08-31', # Defaults to current date
            start_time       => '08:00',      # Must be specified
            months           => [1,3,5],      # Defaults to all
            which_occurrence => first,        # Must be specified
            day_of_week      => [mon],        # Must be specified
          }

          # Run daily repeating every 30 minutes between 9am and 5pm (480 minutes) starting after August 31st, 2011.
          trigger => {
            schedule         => daily,
            start_date       => '2011-08-31', # Defaults to current date
            start_time       => '8:00',       # Must be specified
            minutes_interval => 30,
            minutes_duration => 480,
          }

    EOT

    validate do |value|
      provider.validate_trigger(value)
    end

    def insync?(current)
      provider.trigger_insync?(current, @should)
    end

    def should_to_s(new_value=@should)
      super(new_value)
    end

    def is_to_s(current_value=@is)
      super(current_value)
    end
  end
end
