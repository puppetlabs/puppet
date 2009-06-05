module Puppet
    newtype(:schedule) do
        @doc = "Defined schedules for Puppet.  The important thing to understand
            about how schedules are currently implemented in Puppet is that they
            can only be used to stop a resource from being applied, they never
            guarantee that it is applied.

            Every time Puppet applies its configuration, it will collect the
            list of resources whose schedule does not eliminate them from
            running right then, but there is currently no system in place to
            guarantee that a given resource runs at a given time.  If you
            specify a very  restrictive schedule and Puppet happens to run at a
            time within that schedule, then the resources will get applied;
            otherwise, that work may never get done.

            Thus, it behooves you to use wider scheduling (e.g., over a couple of
            hours) combined with periods and repetitions.  For instance, if you
            wanted to restrict certain resources to only running once, between
            the hours of two and 4 AM, then you would use this schedule::

                schedule { maint:
                    range => \"2 - 4\",
                    period => daily,
                    repeat => 1
                }

            With this schedule, the first time that Puppet runs between 2 and 4 AM,
            all resources with this schedule will get applied, but they won't
            get applied again between 2 and 4 because they will have already
            run once that day, and they won't get applied outside that schedule
            because they will be outside the scheduled range.

            Puppet automatically creates a schedule for each valid period with the
            same name as that period (e.g., hourly and daily).  Additionally,
            a schedule named *puppet* is created and used as the default,
            with the following attributes::

                schedule { puppet:
                    period => hourly,
                    repeat => 2
                }

            This will cause resources to be applied every 30 minutes by default.
            "

        newparam(:name) do
            desc "The name of the schedule.  This name is used to retrieve the
                schedule when assigning it to an object::

                    schedule { daily:
                        period => daily,
                        range => [2, 4]
                    }

                    exec { \"/usr/bin/apt-get update\":
                        schedule => daily
                    }

                "
            isnamevar
        end

        newparam(:range) do
            desc "The earliest and latest that a resource can be applied.  This
                is always a range within a 24 hour period, and hours must be
                specified in numbers between 0 and 23, inclusive.  Minutes and
                seconds can be provided, using the normal colon as a separator.
                For instance::

                    schedule { maintenance:
                        range => \"1:30 - 4:30\"
                    }

                This is mostly useful for restricting certain resources to being
                applied in maintenance windows or during off-peak hours."

            # This is lame; properties all use arrays as values, but parameters don't.
            # That's going to hurt eventually.
            validate do |values|
                values = [values] unless values.is_a?(Array)
                values.each { |value|
                    unless  value.is_a?(String) and
                            value =~ /\d+(:\d+){0,2}\s*-\s*\d+(:\d+){0,2}/
                        self.fail "Invalid range value '%s'" % value
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

                    if range.length != 2
                        self.fail "Invalid range %s" % value
                    end

                    # Make sure the hours are valid
                    [range[0][0], range[1][0]].each do |n|
                        if n < 0 or n > 23
                            raise ArgumentError, "Invalid hour '%s'" % n
                        end
                    end

                    [range[0][1], range[1][1]].each do |n|
                        if n and (n < 0 or n > 59)
                            raise ArgumentError, "Invalid minute '%s'" % n
                        end
                    end
                    if range[0][0] > range[1][0]
                        self.fail(("Invalid range %s; " % value) +
                            "ranges cannot span days."
                        )
                    end
                    ret << range
                }

                # Now our array of arrays
                ret
            end

            def match?(previous, now)
                # The lowest-level array is of the hour, minute, second triad
                # then it's an array of two of those, to present the limits
                # then it's array of those ranges
                unless @value[0][0].is_a?(Array)
                    @value = [@value]
                end

                @value.each do |value|
                    limits = value.collect do |range|
                        ary = [now.year, now.month, now.day, range[0]]
                        if range[1]
                            ary << range[1]
                        else
                            ary << now.min
                        end

                        if range[2]
                            ary << range[2]
                        else
                            ary << now.sec
                        end

                        time = Time.local(*ary)

                        unless time.hour == range[0]
                            self.devfail(
                                "Incorrectly converted time: %s: %s vs %s" %
                                    [time, time.hour, range[0]]
                            )
                        end

                        time
                    end

                    unless limits[0] < limits[1]
                        self.info(
                        "Assuming upper limit should be that time the next day"
                        )

                        ary = limits[1].to_a
                        ary[3] += 1
                        limits[1] = Time.local(*ary)

                        #self.devfail("Lower limit is above higher limit: %s" %
                        #    limits.inspect
                        #)
                    end

                    #self.info limits.inspect
                    #self.notice now
                    return now.between?(*limits)
                end

                # Else, return false, since our current time isn't between
                # any valid times
                return false
            end
        end

        newparam(:periodmatch) do
            desc "Whether periods should be matched by number (e.g., the two times
                are in the same hour) or by distance (e.g., the two times are
                60 minutes apart)."

            newvalues(:number, :distance)

            defaultto :distance
        end

        newparam(:period) do
            desc "The period of repetition for a resource.  Choose from among
                a fixed list of *hourly*, *daily*, *weekly*, and *monthly*.
                The default is for a resource to get applied every time that
                Puppet runs, whatever that period is.

                Note that the period defines how often a given resource will get
                applied but not when; if you would like to restrict the hours
                that a given resource can be applied (e.g., only at night during
                a maintenance window) then use the ``range`` attribute.

                If the provided periods are not sufficient, you can provide a
                value to the *repeat* attribute, which will cause Puppet to
                schedule the affected resources evenly in the period the
                specified number of times.  Take this schedule::

                    schedule { veryoften:
                        period => hourly,
                        repeat => 6
                    }

                This can cause Puppet to apply that resource up to every 10 minutes.

                At the moment, Puppet cannot guarantee that level of
                repetition; that is, it can run up to every 10 minutes, but
                internal factors might prevent it from actually running that
                often (e.g., long-running Puppet runs will squash conflictingly
                scheduled runs).

                See the ``periodmatch`` attribute for tuning whether to match
                times by their distance apart or by their specific value."

            newvalues(:hourly, :daily, :weekly, :monthly, :never)

            @@scale = {
                :hourly => 3600,
                :daily => 86400,
                :weekly => 604800,
                :monthly => 2592000
            }
            @@methods = {
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
                    method = @@methods[value]
                    if method.is_a?(Proc)
                        return method.call(previous, now)
                    else
                        # We negate it, because if they're equal we don't run
                        return now.send(method) != previous.send(method)
                    end
                when :distance
                    scale = @@scale[value]

                    # If the number of seconds between the two times is greater
                    # than the unit of time, we match.  We divide the scale
                    # by the repeat, so that we'll repeat that often within
                    # the scale.
                    diff = (now.to_i - previous.to_i)
                    comparison = (scale / @resource[:repeat])

                    return (now.to_i - previous.to_i) >= (scale / @resource[:repeat])
                end
            end
        end

        newparam(:repeat) do
            desc "How often the application gets repeated in a given period.
                Defaults to 1. Must be an integer."

            defaultto 1

            validate do |value|
                unless value.is_a?(Integer) or value =~ /^\d+$/
                    raise Puppet::Error,
                        "Repeat must be a number"
                end

                # This implicitly assumes that 'periodmatch' is distance -- that
                # is, if there's no value, we assume it's a valid value.
                return unless @resource[:periodmatch]

                if value != 1 and @resource[:periodmatch] != :distance
                    raise Puppet::Error,
                        "Repeat must be 1 unless periodmatch is 'distance', not '%s'" %
                            @resource[:periodmatch]
                end
            end

            munge do |value|
                unless value.is_a?(Integer)
                    value = Integer(value)
                end

                value
            end

            def match?(previous, now)
                true
            end
        end

        def self.instances
            []
        end

        def self.mkdefaultschedules
            result = []
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
            if previous
                previous = Time.at(previous)
            end

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
            return true
        end
    end
end

