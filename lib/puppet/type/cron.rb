require 'etc'
require 'facter'
require 'puppet/util/filetype'

Puppet::Type.newtype(:cron) do
    @doc = "Installs and manages cron jobs.  All fields except the command
        and the user are optional, although specifying no periodic
        fields would result in the command being executed every
        minute.  While the name of the cron job is not part of the actual
        job, it is used by Puppet to store and retrieve it.

        If you specify a cron job that matches an existing job in every way
        except name, then the jobs will be considered equivalent and the
        new name will be permanently associated with that job.  Once this
        association is made and synced to disk, you can then manage the job
        normally (e.g., change the schedule of the job).

        Example::

            cron { logrotate:
                command => \"/usr/sbin/logrotate\",
                user => root,
                hour => 2,
                minute => 0
            }

        Note that all cron values can be specified as an array of values::

            cron { logrotate:
                command => \"/usr/sbin/logrotate\",
                user => root,
                hour => [2, 4]
            }

        Or using ranges, or the step syntax ``*/2`` (although there's no guarantee that
        your ``cron`` daemon supports it)::

            cron { logrotate:
                command => \"/usr/sbin/logrotate\",
                user => root,
                hour => ['2-4'],
                minute => '*/10'
            }
        "
    ensurable

    # A base class for all of the Cron parameters, since they all have
    # similar argument checking going on.
    class CronParam < Puppet::Property
        class << self
            attr_accessor :boundaries, :default
        end

        # We have to override the parent method, because we consume the entire
        # "should" array
        def insync?(is)
            if defined? @should and @should
                self.is_to_s(is) == self.should_to_s
            else
                true
            end
        end

        # A method used to do parameter input handling.  Converts integers
        # in string form to actual integers, and returns the value if it's
        # an integer or false if it's just a normal string.
        def numfix(num)
            if num =~ /^\d+$/
                return num.to_i
            elsif num.is_a?(Integer)
                return num
            else
                return false
            end
        end

        # Verify that a number is within the specified limits.  Return the
        # number if it is, or false if it is not.
        def limitcheck(num, lower, upper)
            if num >= lower and num <= upper
                return num
            else
                return false
            end
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
                    if name =~ /#{tmp}/i
                        return index
                    end
                }
            else
                if ary.include?(tmp)
                    return ary.index(tmp)
                end
            end

            return false
        end

        def should_to_s(newvalue = @should)
            if newvalue
                unless newvalue.is_a?(Array)
                    newvalue = [newvalue]
                end
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
                unless currentvalue.is_a?(Array)
                    return currentvalue
                end

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
            if value == "absent" or value == :absent
                return :absent
            end

            # Allow the */2 syntax
            if value =~ /^\*\/[0-9]+$/
                return value
            end

            # Allow ranges
            if value =~ /^[0-9]+-[0-9]+$/
                return value
            end

            # Allow ranges + */2
            if value =~ /^[0-9]+-[0-9]+\/[0-9]+$/
                return value
            end

            if value == "*"
                return value
            end

            return value unless self.class.boundaries
            lower, upper = self.class.boundaries
            retval = nil
            if num = numfix(value)
                retval = limitcheck(num, lower, upper)
            elsif respond_to?(:alpha)
                # If it has an alpha method defined, then we check
                # to see if our value is in that list and if so we turn
                # it into a number
                retval = alphacheck(value, alpha())
            end

            if retval
                return retval.to_s
            else
                self.fail "%s is not a valid %s" %
                    [value, self.class.name]
            end
        end
    end

    # Somewhat uniquely, this property does not actually change anything -- it
    # just calls +@resource.sync+, which writes out the whole cron tab for
    # the user in question.  There is no real way to change individual cron
    # jobs without rewriting the entire cron file.
    #
    # Note that this means that managing many cron jobs for a given user
    # could currently result in multiple write sessions for that user.
    newproperty(:command, :parent => CronParam) do
        desc "The command to execute in the cron job.  The environment
            provided to the command varies by local system rules, and it is
            best to always provide a fully qualified command.  The user's
            profile is not sourced when the command is run, so if the
            user's environment is desired it should be sourced manually.

            All cron parameters support ``absent`` as a value; this will
            remove any existing values for that field."

        def retrieve
          return_value = super
          if return_value && return_value.is_a?(Array)
            return_value = return_value[0]
          end

          return return_value
        end

        def should
            if @should
                if @should.is_a? Array
                    @should[0]
                else
                    devfail "command is not an array"
                end
            else
                nil
            end
        end
    end

    newproperty(:special) do
        desc "Special schedules only supported on FreeBSD."

        def specials
            %w{reboot yearly annually monthly weekly daily midnight hourly}
        end

        validate do |value|
            unless specials().include?(value)
                raise ArgumentError, "Invalid special schedule %s" %
                    value.inspect
            end
        end
    end

    newproperty(:minute, :parent => CronParam) do
        self.boundaries = [0, 59]
        desc "The minute at which to run the cron job.
            Optional; if specified, must be between 0 and 59, inclusive."
    end

    newproperty(:hour, :parent => CronParam) do
        self.boundaries = [0, 23]
        desc "The hour at which to run the cron job. Optional;
            if specified, must be between 0 and 23, inclusive."
    end

    newproperty(:weekday, :parent => CronParam) do
        def alpha
            %w{sunday monday tuesday wednesday thursday friday saturday}
        end
        self.boundaries = [0, 7]
        desc "The weekday on which to run the command.
            Optional; if specified, must be between 0 and 7, inclusive, with
            0 (or 7) being Sunday, or must be the name of the day (e.g., Tuesday)."
    end

    newproperty(:month, :parent => CronParam) do
        def alpha
            %w{january february march april may june july
                august september october november december}
        end
        self.boundaries = [1, 12]
        desc "The month of the year.  Optional; if specified
            must be between 1 and 12 or the month name (e.g., December)."
    end

    newproperty(:monthday, :parent => CronParam) do
        self.boundaries = [1, 31]
        desc "The day of the month on which to run the
            command.  Optional; if specified, must be between 1 and 31."
    end

    newproperty(:environment) do
        desc "Any environment settings associated with this cron job.  They
            will be stored between the header and the job in the crontab.  There
            can be no guarantees that other, earlier settings will not also
            affect a given cron job.


            Also, Puppet cannot automatically determine whether an existing,
            unmanaged environment setting is associated with a given cron
            job.  If you already have cron jobs with environment settings,
            then Puppet will keep those settings in the same place in the file,
            but will not associate them with a specific job.

            Settings should be specified exactly as they should appear in
            the crontab, e.g., ``PATH=/bin:/usr/bin:/usr/sbin``."

        validate do |value|
            unless value =~ /^\s*(\w+)\s*=\s*(.*)\s*$/ or value == :absent or value == "absent"
                raise ArgumentError, "Invalid environment setting %s" %
                    value.inspect
            end
        end

        def insync?(is)
            if is.is_a? Array
                return is.sort == @should.sort
            else
                return is == @should
            end
        end

        def is_to_s(newvalue)
            if newvalue
                if newvalue.is_a?(Array)
                    newvalue.join(",")
                else
                    newvalue
                end
            else
                nil
            end
        end

        def should
            @should
        end

        def should_to_s(newvalue = @should)
            if newvalue
                newvalue.join(",")
            else
                nil
            end
        end
    end

    newparam(:name) do
        desc "The symbolic name of the cron job.  This name
            is used for human reference only and is generated automatically
            for cron jobs found on the system.  This generally won't
            matter, as Puppet will do its best to match existing cron jobs
            against specified jobs (and Puppet adds a comment to cron jobs it
            adds), but it is at least possible that converting from
            unmanaged jobs to managed jobs might require manual
            intervention."

        isnamevar
    end

    newproperty(:user) do
        desc "The user to run the command as.  This user must
            be allowed to run cron jobs, which is not currently checked by
            Puppet.

            The user defaults to whomever Puppet is running as."

        defaultto { Etc.getpwuid(Process.uid).name || "root" }
    end

    newproperty(:target) do
        desc "Where the cron job should be stored.  For crontab-style
            entries this is the same as the user and defaults that way.
            Other providers default accordingly."

        defaultto {
            if provider.is_a?(@resource.class.provider(:crontab))
                if val = @resource.should(:user)
                    val
                else
                    raise ArgumentError,
                        "You must provide a user with crontab entries"
                end
            elsif provider.class.ancestors.include?(Puppet::Provider::ParsedFile)
                provider.class.default_target
            else
                nil
            end
        }
    end

    # We have to reorder things so that :provide is before :target

    attr_accessor :uid

    def value(name)
        name = symbolize(name)
        ret = nil
        if obj = @parameters[name]
            ret = obj.should

            if ret.nil?
                ret = obj.retrieve
            end

            if ret == :absent
                ret = nil
            end
        end

        unless ret
            case name
            when :command
                devfail "No command, somehow"
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



