# frozen_string_literal: true

module Puppet
  Type.newtype(:schedule) do
    @doc = <<-'EOT'
      Define schedules for Puppet. Resources can be limited to a schedule by using the
      [`schedule`](https://puppet.com/docs/puppet/latest/metaparameter.html#schedule)
      metaparameter.

      Currently, **schedules can only be used to stop a resource from being
      applied;** they cannot cause a resource to be applied when it otherwise
      wouldn't be, and they cannot accurately specify a time when a resource
      should run.

      Every time Puppet applies its configuration, it will apply the
      set of resources whose schedule does not eliminate them from
      running right then, but there is currently no system in place to
      guarantee that a given resource runs at a given time.  If you
      specify a very  restrictive schedule and Puppet happens to run at a
      time within that schedule, then the resources will get applied;
      otherwise, that work may never get done.

      Thus, it is advisable to use wider scheduling (for example, over a couple
      of hours) combined with periods and repetitions.  For instance, if you
      wanted to restrict certain resources to only running once, between
      the hours of two and 4 AM, then you would use this schedule:

          schedule { 'maint':
            range  => '2 - 4',
            period => daily,
            repeat => 1,
          }

      With this schedule, the first time that Puppet runs between 2 and 4 AM,
      all resources with this schedule will get applied, but they won't
      get applied again between 2 and 4 because they will have already
      run once that day, and they won't get applied outside that schedule
      because they will be outside the scheduled range.

      Puppet automatically creates a schedule for each of the valid periods
      with the same name as that period (such as hourly and daily).
      Additionally, a schedule named `puppet` is created and used as the
      default, with the following attributes:

          schedule { 'puppet':
            period => hourly,
            repeat => 2,
          }

      This will cause resources to be applied every 30 minutes by default.

      The `statettl` setting on the agent affects the ability of a schedule to
      determine if a resource has already been checked. If the `statettl` is
      set lower than the span of the associated schedule resource, then a
      resource could be checked & applied multiple times in the schedule as
      the information about when the resource was last checked will have
      expired from the cache.
    EOT

    apply_to_all

    newparam(:name) do
      desc <<-EOT
        The name of the schedule.  This name is used when assigning the schedule
        to a resource with the `schedule` metaparameter:

            schedule { 'everyday':
              period => daily,
              range  => '2 - 4',
            }

            exec { '/usr/bin/apt-get update':
              schedule => 'everyday',
            }

      EOT
      isnamevar
    end

    newparam(:range) do
      desc <<-EOT
        The earliest and latest that a resource can be applied.  This is
        always a hyphen-separated range within a 24 hour period, and hours
        must be specified in numbers between 0 and 23, inclusive.  Minutes and
        seconds can optionally be provided, using the normal colon as a
        separator. For instance:

            schedule { 'maintenance':
              range => '1:30 - 4:30',
            }

        This is mostly useful for restricting certain resources to being
        applied in maintenance windows or during off-peak hours. Multiple
        ranges can be applied in array context. As a convenience when specifying
        ranges, you can cross midnight (for example, `range => "22:00 - 04:00"`).
      EOT

      # This is lame; properties all use arrays as values, but parameters don't.
      # That's going to hurt eventually.
      validate do |values|
        values = [values] unless values.is_a?(Array)
        values.each { |value|
          unless value.is_a?(String) and
                 value =~ /\d+(:\d+){0,2}\s*-\s*\d+(:\d+){0,2}/
            self.fail _("Invalid range value '%{value}'") % { value: value }
          end
        }
      end

      munge do |values|
        values = [values] unless values.is_a?(Array)
        ret = []

        values.each { |value|
          range = []
          # Split each range value into a hour, minute, second triad
          value.split(/\s*-\s*/).each { |val|
            # Add the values as an array.
            range << val.split(":").collect { |n| n.to_i }
          }

          self.fail _("Invalid range %{value}") % { value: value } if range.length != 2

          # Fill out 0s for unspecified minutes and seconds
          range.each do |time_array|
            (3 - time_array.length).times { |_| time_array << 0 }
          end

          # Make sure the hours are valid
          [range[0][0], range[1][0]].each do |n|
            raise ArgumentError, _("Invalid hour '%{n}'") % { n: n } if n < 0 or n > 23
          end

          [range[0][1], range[1][1]].each do |n|
            raise ArgumentError, _("Invalid minute '%{n}'") % { n: n } if n and (n < 0 or n > 59)
          end
          ret << range
        }

        # Now our array of arrays
        ret
      end

      def weekday_match?(day)
        if @resource[:weekday]
          @resource[:weekday].has_key?(day)
        else
          true
        end
      end

      def match?(previous, now)
        # The lowest-level array is of the hour, minute, second triad
        # then it's an array of two of those, to present the limits
        # then it's an array of those ranges
        @value = [@value] unless @value[0][0].is_a?(Array)
        @value.any? do |range|
          limit_start = Time.local(now.year, now.month, now.day, *range[0])
          limit_end = Time.local(now.year, now.month, now.day, *range[1])

          if limit_start < limit_end
            # The whole range is in one day, simple case
            now.between?(limit_start, limit_end) && weekday_match?(now.wday)
          else
            # The range spans days. We have to test against a range starting
            # today, and a range that started yesterday.
            today = Date.new(now.year, now.month, now.day)
            tomorrow = today.next_day
            yesterday = today.prev_day

            # First check a range starting today
            if now.between?(limit_start, Time.local(tomorrow.year, tomorrow.month, tomorrow.day, *range[1]))
              weekday_match?(today.wday)
            else
              # Then check a range starting yesterday
              now.between?(Time.local(yesterday.year, yesterday.month, yesterday.day, *range[0]),
                           limit_end) &&
                weekday_match?(yesterday.wday)
            end
          end
        end
      end
    end

    newparam(:periodmatch) do
      desc "Whether periods should be matched by a numeric value (for instance,
        whether two times are in the same hour) or by their chronological
        distance apart (whether two times are 60 minutes apart)."

      newvalues(:number, :distance)

      defaultto :distance
    end

    newparam(:period) do
      desc <<-EOT
        The period of repetition for resources on this schedule. The default is
        for resources to get applied every time Puppet runs.

        Note that the period defines how often a given resource will get
        applied but not when; if you would like to restrict the hours
        that a given resource can be applied (for instance, only at night
        during a maintenance window), then use the `range` attribute.

        If the provided periods are not sufficient, you can provide a
        value to the *repeat* attribute, which will cause Puppet to
        schedule the affected resources evenly in the period the
        specified number of times.  Take this schedule:

            schedule { 'veryoften':
              period => hourly,
              repeat => 6,
            }

        This can cause Puppet to apply that resource up to every 10 minutes.

        At the moment, Puppet cannot guarantee that level of repetition; that
        is, the resource can applied _up to_ every 10 minutes, but internal
        factors might prevent it from actually running that often (for instance,
        if a Puppet run is still in progress when the next run is scheduled to
        start, that next run will be suppressed).

        See the `periodmatch` attribute for tuning whether to match
        times by their distance apart or by their specific value.

        > **Tip**: You can use `period => never,` to prevent a resource from being applied
        in the given `range`. This is useful if you need to create a blackout window to
        perform sensitive operations without interruption.
      EOT

      newvalues(:hourly, :daily, :weekly, :monthly, :never)

      ScheduleScales = {
        :hourly => 3600,
        :daily => 86_400,
        :weekly => 604_800,
        :monthly => 2_592_000
      }
      ScheduleMethods = {
        :hourly => :hour,
        :daily => :day,
        :monthly => :month,
        :weekly => proc do |prev, now|
          # Run the resource if the previous day was after this weekday (e.g., prev is wed, current is tue)
          # or if it's been more than a week since we ran
          prev.wday > now.wday or (now - prev) > (24 * 3600 * 7)
        end
      }

      def match?(previous, now)
        return false if value == :never

        value = self.value
        case @resource[:periodmatch]
        when :number
          method = ScheduleMethods[value]
          if method.is_a?(Proc)
            return method.call(previous, now)
          else
            # We negate it, because if they're equal we don't run
            return now.send(method) != previous.send(method)
          end
        when :distance
          scale = ScheduleScales[value]

          # If the number of seconds between the two times is greater
          # than the unit of time, we match.  We divide the scale
          # by the repeat, so that we'll repeat that often within
          # the scale.
          return (now.to_i - previous.to_i) >= (scale / @resource[:repeat])
        end
      end
    end

    newparam(:repeat) do
      desc "How often a given resource may be applied in this schedule's `period`.
        Must be an integer."

      defaultto 1

      validate do |value|
        unless value.is_a?(Integer) or value =~ /^\d+$/
          raise Puppet::Error,
                _("Repeat must be a number")
        end

        # This implicitly assumes that 'periodmatch' is distance -- that
        # is, if there's no value, we assume it's a valid value.
        return unless @resource[:periodmatch]

        if value != 1 and @resource[:periodmatch] != :distance
          raise Puppet::Error,
                _("Repeat must be 1 unless periodmatch is 'distance', not '%{period}'") % { period: @resource[:periodmatch] }
        end
      end

      munge do |value|
        value = Integer(value) unless value.is_a?(Integer)

        value
      end

      def match?(previous, now)
        true
      end
    end

    newparam(:weekday) do
      desc <<-EOT
        The days of the week in which the schedule should be valid.
        You may specify the full day name 'Tuesday', the three character
        abbreviation 'Tue', or a number (as a string or as an integer) corresponding to the day of the
        week where 0 is Sunday, 1 is Monday, and so on. Multiple days can be specified
        as an array. If not specified, the day of the week will not be
        considered in the schedule.

        If you are also using a range match that spans across midnight
        then this parameter will match the day that it was at the start
        of the range, not necessarily the day that it is when it matches.
        For example, consider this schedule:

            schedule { 'maintenance_window':
              range   => '22:00 - 04:00',
              weekday => 'Saturday',
            }

        This will match at 11 PM on Saturday and 2 AM on Sunday, but not
        at 2 AM on Saturday.
      EOT

      validate do |values|
        values = [values] unless values.is_a?(Array)
        values.each { |value|
          if weekday_integer?(value) || weekday_string?(value)
            value
          else
            raise ArgumentError, _("%{value} is not a valid day of the week") % { value: value }
          end
        }
      end

      def weekday_integer?(value)
        value.is_a?(Integer) && (0..6).cover?(value)
      end

      def weekday_string?(value)
        value.is_a?(String) && (value =~ /^[0-6]$/ || value =~ /^(Mon|Tues?|Wed(?:nes)?|Thu(?:rs)?|Fri|Sat(?:ur)?|Sun)(day)?$/i)
      end

      weekdays = {
        'sun' => 0,
        'mon' => 1,
        'tue' => 2,
        'wed' => 3,
        'thu' => 4,
        'fri' => 5,
        'sat' => 6,
      }

      munge do |values|
        values = [values] unless values.is_a?(Array)
        ret = {}

        values.each do |value|
          case value
          when /^[0-6]$/
            index = value.to_i
          when 0..6
            index = value
          else
            index = weekdays[value[0, 3].downcase]
          end
          ret[index] = true
        end
        ret
      end

      def match?(previous, now)
        # Special case weekday matching with ranges to a no-op here.
        # If the ranges span days then we can't simply match the current
        # weekday, as we want to match the weekday as it was when the range
        # started.  As a result, all of that logic is in range, not here.
        return true if @resource[:range]

        return true if value.has_key?(now.wday)

        false
      end
    end

    def self.instances
      []
    end

    def self.mkdefaultschedules
      result = []
      unless Puppet[:default_schedules]
        Puppet.debug "Not creating default schedules: default_schedules is false"
        return result
      end

      Puppet.debug "Creating default schedules"

      result << self.new(
        :name => "puppet",
        :period => :hourly,

        :repeat => "2"
      )

      # And then one for every period
      @parameters.find { |p| p.name == :period }.value_collection.values.each { |value|
        result << self.new(
          :name => value.to_s,
          :period => value
        )
      }

      result
    end

    def match?(previous = nil, now = nil)
      # If we've got a value, then convert it to a Time instance
      previous &&= Time.at(previous)

      now ||= Time.now

      # Pull them in order
      self.class.allattrs.each { |param|
        if @parameters.include?(param) and
           @parameters[param].respond_to?(:match?)
          return false unless @parameters[param].match?(previous, now)
        end
      }

      # If we haven't returned false, then return true; in other words,
      # any provided schedules need to all match
      true
    end
  end
end
