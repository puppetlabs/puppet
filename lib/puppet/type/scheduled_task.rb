require 'puppet/util/adsi'

Puppet::Type.newtype(:scheduled_task) do
  @doc = "Installs and manages scheduled tasks. All fields except the
    name and command are optional; specifying no scheduling parameters
    will result in the task being created and executed once on the next
    minute. The name of the task is not part of the actual job, but is
    used by Puppet and the underlying provider to store and retrieve it.

    Scheduling parameters are interpreted somewhat differently by the Windows
    provider: the hour, month, weekday, et. al. properties specify the
    starting date and time for the scheduled event. It is the 'repeat' property
    that defines how frequently the task will be repeated.

    Windows tasks have several limitations over that standard Puppet cron
    type: the wildcard ('*') value is generally not supported, rather the
    various repeat periods (hourly, daily, etc.) imply all values.
    Range specifications such as '[2-4]' and '*/2' are likewise not supported.

    Examples:

      # Creates a task that runs at 2:00am everyday
      scheduled_task { facter-daily:
        command => 'c:/ruby/187/bin/facter.bat > c:\\facter-dump.log,
        hour => 2,
        minute => 0
        repeat => daily
      }

      # Creates an hourly task starting 1 minute past the hour
      scheduled_task { facter-hourly-debug:
        ensure => present,
        command => 'c:\ruby\bin\facter.bat --debug  > c:\\facter-dump.log',
        minute => 1,
        repeat => 'hourly',
      }"


  ensurable

  feature :create, "The provider can create a scheduled task",
    :methods => [:create]

  feature :delete, "The provider can delete a scheduled task.",
    :methods => [:delete]

  feature :enableable, "The provider can enable and disable the scheduled task.",
    :methods => [:disable, :enable, :enabled?]

  newproperty(:enable, :required_features => :enableable) do
    desc "Whether a scheduled task should be enabled to start. This property
      behaves quite differently depending on the platform; wherever possible,
      it relies on local tools to enable or disable a scheduled task."

    newvalue(:true, :event => :task_enabled) do
      provider.enable
    end

    newvalue(:false, :event => :task_disabled) do
      provider.disable
    end

    def retrieve
      provider.enabled?
    end

   defaultto :true
  end

  # A base class for all of scheduled task parameters, since they all have
  # similar argument checking going on.
  class ScheduledTaskParam < Puppet::Property

    @doc = "All schduled task parameters support `:absent` as a value. The behaviour when using
    'absent' is defined by the provider. On Windows, this assumes the current or default value
    for that field. An existing schedule value is unchanged if a property is later set to :absent."

    class << self
      attr_accessor :boundaries, :default
    end

    # We have to override the parent method, because we consume the entire
    # "should" array
    def insync?(is)
      self.is_to_s(is) == self.should_to_s
    end

    # A method used to do parameter input handling.  Converts integers
    # in string form to actual integers, and returns the value if it's
    # an integer or false if it's just a normal string.
    def numfix(num)
      Integer(num) rescue false
    end

    # Verify that a number is within the specified limits.  Return the
    # number if it is, or false if it is not.
    def limitcheck(num, lower, upper)
      num.between? lower, upper ? num : false
    end

    # Verify that a value falls within the specified array.  Does case
    # insensitive matching, and supports matching either the entire word
    # or the first three letters of the word.
    def alphacheck(value, ary)
      tmp = value.downcase

      # If they specified a shortened version of the name, then see
      # if we can lengthen it (e.g., mon => monday).
      if tmp.length == 3
        ary.each_with_index { |name, index|
          if name =~ /^#{tmp}/i
            return index
          end
        }
      else
        return ary.index(tmp) if ary.include?(tmp)
      end

      false
    end

    def should_to_s(newvalue = @should)
      if newvalue
        newvalue = [newvalue] unless newvalue.is_a?(Array)
        if self.name == :command or newvalue[0].is_a? Symbol
          newvalue[0]
        else
          newvalue.join(",")
        end
      else
        nil
      end
    end

    def is_to_s(currentvalue = @is)
      if currentvalue
        return currentvalue unless currentvalue.is_a?(Array)

        if self.name == :command or currentvalue[0].is_a? Symbol
          currentvalue[0]
        else
          currentvalue.join(",")
        end
      else
        nil
      end
    end

    def should
      if @should and @should[0] == :absent
        :absent
      else
        @should
      end
    end

    def should=(ary)
      super
      @should.flatten!
    end

    # The method that does all of the actual parameter value
    # checking; called by all of the +param<name>=+ methods.
    # Requires the value, type, and bounds, and optionally supports
    # a boolean of whether to do alpha checking, and if so requires
    # the ary against which to do the checking.
    munge do |value|
      # Support 'absent' as a value, so that they can remove
      # a value
      return :absent if [ "absent", :absent, "*" ].include?( value )

      return value unless self.class.boundaries
      lower, upper = self.class.boundaries
      retval = nil
      if num = numfix(value)
        self.fail "#{num} (#{self.class.name}) must be in the range [#{lower}, #{upper}]" unless num.between? lower, upper
        retval = num
      elsif respond_to?(:alpha)
        # If it has an alpha method defined, then we check
        # to see if our value is in that list and if so we turn
        # it into a number
        retval = alphacheck(value, alpha)
      end

      if retval
        return retval.to_s
      else
        self.fail "#{value} is not a valid #{self.class.name}"
      end
    end
  end

  newproperty(:command, :parent => ScheduledTaskParam) do
    desc "The command to execute in the scheduled task. The environment provided to the
      command varies by local system rules, and it is best to always provide a
      fully qualified command. The user's profile is not sourced when the
      command is run, so if the user's environment is desired it should be
      sourced manually by the specfied command."

    def retrieve
      return_value = super
      return_value = return_value[0] if return_value && return_value.is_a?(Array)

      return_value
    end

    def should
      devfail "command must be an Array not a '#{@should.class}'" if @should and !@should.is_a?(Array)
      @should[0] if @should
    end

    if Puppet.features.microsoft_windows?
      munge do |value|
        # tokenize by quoted args first(' or ")
        bin_ary = value.scan(/.*["'](.*)['"](.*)/).flatten
        # tokenize by spaces if no quoted args found
        bin_ary = value.split if bin_ary.empty?
        bin_ary.each{ |p| p.strip! }
        # delete any empty/nil values
        bin_ary.delete_if{ |p| p.nil? || p.empty?}
        # quote the command argument
        bin_ary[0] = "\"#{bin_ary[0]}\"" if( !bin_ary.empty? && bin_ary[0].include?(' ') )
        # join the returned value
        value = bin_ary.join ' '
        # normalize to forward (*nix) path seperators
        value = value.gsub('\\\\', '/').gsub('\\', '/')
      end
    end
  end

  newproperty(:minute, :parent => ScheduledTaskParam) do
    self.boundaries = [0, 59]
    desc "The minute at which to run the task. Optional; if specified,
      must be between 0 and 59, inclusive. Wildcard ('*') is not supported."
    validate do |value|
      if Puppet.features.microsoft_windows? && value ==  '*'
        raise ArgumentError, "Invalid setting #{value.inspect}: Windows does not support wildcard for minute field."
      end
    end
  end

  newproperty(:hour, :parent => ScheduledTaskParam) do
    self.boundaries = [0, 23]
    desc "The hour at which to run the task. Optional;
      if specified, must be between 0 and 23, inclusive."
  end

  newproperty(:weekday, :parent => ScheduledTaskParam) do
    def alpha
      %w{sunday monday tuesday wednesday thursday friday saturday}
    end
    self.boundaries = [0, 7]
    desc "The weekday on which to run the command.
      Optional; if specified, must be between 0 and 7, inclusive, with
      0 (or 7) being Sunday, or must be the name of the day (e.g., Tuesday)."
  end

  newproperty(:month, :parent => ScheduledTaskParam) do
    def alpha
      %w{january february march april may june july
        august september october november december}
    end
    self.boundaries = [1, 12]
    desc "The month of the year.  Optional; if specified
      must be between 1 and 12 or the month name (e.g., December)."
end

  newproperty(:monthday, :parent => ScheduledTaskParam) do
    self.boundaries = [1, 31]
    desc "The day of the month on which to run the
      command.  Optional; if specified, must be between 1 and 31."
  end

  newproperty(:repeat, :parent => ScheduledTaskParam) do
    def alpha
      %w{daily weekly monthly hourly once}
    end
    self.boundaries = [0, 4]
    desc "Optional task repeat period.
      If specified, must be between 0 and 4, inclusive, with
      0 being 'daily' or must be the name of the literal string (e.g., daily)."

    defaultto 0
  end

  newparam(:name) do
    desc "The symbolic name of the scheduled job. This name is used for human
      reference only and is generated automatically for scheduled jobs found
      on the system. This generally won't matter, as Puppet will do its best
      to match existing jobs against specified jobs (and Puppet adds a comment
      to scheduled jobs it adds), but it is at least possible that converting from
      unmanaged jobs to managed jobs might require manual intervention."

    isnamevar
  end

  newparam(:purge, :boolean => true) do
    desc "Cleanse expired or execute-once tasks."
    defaultto :false
    newvalues(:true, :false)
  end

  # Purging?
  def purge?
    @parameters.include?(:purge) and (self[:purge] == :true or self[:purge] == "true")
  end

  # We have to reorder things so that :provide is before :target

  attr_accessor :uid

  def value(name)
    name = symbolize(name)
    ret = nil
    if obj = @parameters[name]
      ret = obj.should

      ret ||= obj.retrieve

      if ret == :absent
        ret = nil
      end
    end

    unless ret
      case name
      when :command
        devfail "No command, somehow" unless @parameters[:ensure].value == :absent
      when :special
        # nothing
      else
        #ret = (self.class.validproperty?(name).default || "*").to_s
        ret = "*"
      end
    end

    ret
  end

end
