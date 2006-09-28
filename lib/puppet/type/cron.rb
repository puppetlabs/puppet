require 'etc'
require 'facter'
require 'puppet/type/state'
require 'puppet/filetype'
require 'puppet/type/parsedtype'

module Puppet
    # Model the actual cron jobs.  Supports all of the normal cron job fields
    # as parameters, with the 'command' as the single state.  Also requires a
    # completely symbolic 'name' paremeter, which gets written to the file
    # and is used to manage the job.
    newtype(:cron) do

        # A base class for all of the Cron parameters, since they all have
        # similar argument checking going on.  We're stealing the base class
        # from parsedtype, and we should probably subclass Cron from there,
        # but it was just too annoying to do.
        class CronParam < Puppet::State::ParsedParam
            class << self
                attr_accessor :boundaries, :default
            end

            # We have to override the parent method, because we consume the entire
            # "should" array
            def insync?
                if defined? @should and @should
                    self.is_to_s == self.should_to_s
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

            def should_to_s
                if @should
                    if self.name == :command or @should[0].is_a? Symbol
                        @should[0]
                    else
                        @should.join(",")
                    end
                else
                    nil
                end
            end

            def is_to_s
                if @is
                    unless @is.is_a?(Array)
                        return @is
                    end

                    if self.name == :command or @is[0].is_a? Symbol
                        @is[0]
                    else
                        @is.join(",")
                    end
                else
                    nil
                end
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


        # Override 'newstate' so that all states default to having the
        # correct parent type
        def self.newstate(name, options = {}, &block)
            options[:parent] ||= Puppet::State::CronParam
            super(name, options, &block)
        end

        # Somewhat uniquely, this state does not actually change anything -- it
        # just calls +@parent.sync+, which writes out the whole cron tab for
        # the user in question.  There is no real way to change individual cron
        # jobs without rewriting the entire cron file.
        #
        # Note that this means that managing many cron jobs for a given user
        # could currently result in multiple write sessions for that user.
        newstate(:command, :parent => CronParam) do
            desc "The command to execute in the cron job.  The environment
                provided to the command varies by local system rules, and it is
                best to always provide a fully qualified command.  The user's
                profile is not sourced when the command is run, so if the
                user's environment is desired it should be sourced manually.
                
                All cron parameters support ``absent`` as a value; this will
                remove any existing values for that field."

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

        newstate(:special, :parent => Puppet::State::ParsedParam) do
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

        newstate(:minute) do
            self.boundaries = [0, 59]
            desc "The minute at which to run the cron job.
                Optional; if specified, must be between 0 and 59, inclusive."
        end

        newstate(:hour) do
            self.boundaries = [0, 23]
            desc "The hour at which to run the cron job. Optional;
                if specified, must be between 0 and 23, inclusive."
        end

        newstate(:weekday) do
            def alpha
                %w{sunday monday tuesday wednesday thursday friday saturday}
            end
            self.boundaries = [0, 6]
            desc "The weekday on which to run the command.
                Optional; if specified, must be between 0 and 6, inclusive, with
                0 being Sunday, or must be the name of the day (e.g., Tuesday)."
        end

        newstate(:month) do
            def alpha
                %w{january february march april may june july
                    august september october november december}
            end
            self.boundaries = [1, 12]
            desc "The month of the year.  Optional; if specified
                must be between 1 and 12 or the month name (e.g., December)."
        end

        newstate(:monthday) do
            self.boundaries = [1, 31]
            desc "The day of the month on which to run the
                command.  Optional; if specified, must be between 1 and 31."
        end

        newstate(:environment, :parent => Puppet::State::ParsedParam) do
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
                the crontab, e.g., 'PATH=/bin:/usr/bin:/usr/sbin'.  Multiple
                settings should be specified as an array."

            validate do |value|
                unless value =~ /^\s*(\w+)\s*=\s*(.+)\s*$/
                    raise ArgumentError, "Invalid environment setting %s" %
                        value.inspect
                end
            end

            def insync?
                if @is.is_a? Array
                    return @is.sort == @should.sort
                else
                    return @is == @should
                end
            end

            def should
                @should
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
                intervention.
                
                The names can only have alphanumeric characters plus the '-'
                character."

            isnamevar

            validate do |value|
                unless value =~ /^[-\w]+$/
                    raise ArgumentError, "Invalid name format '%s'" % value
                end
            end
        end

        newparam(:user) do
            desc "The user to run the command as.  This user must
                be allowed to run cron jobs, which is not currently checked by
                Puppet.
                
                The user defaults to whomever Puppet is running as."

            defaultto { ENV["USER"] }

            def value=(value)
                super

                # Make sure the user is not an array
                if @value.is_a? Array
                    @value = @value[0]
                end
            end
        end

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
            
            Example:
                
                cron { logrotate:
                    command => \"/usr/sbin/logrotate\",
                    user => root,
                    hour => 2,
                    minute => 0
                }
            "

        @instances = {}
        @tabs = {}

        class << self
            attr_accessor :filetype

            def cronobj(name)
                if defined? @tabs
                    return @tabs[name]
                else
                    return nil
                end
            end
        end

        attr_accessor :uid

        # In addition to removing the instances in @objects, Cron has to remove
        # per-user cron tab information.
        def self.clear
            @instances = {}
            @tabs = {}
            super
        end

        def self.defaulttype
            case Facter["operatingsystem"].value
            when "Solaris":
                return Puppet::FileType.filetype(:suntab)
            else
                return Puppet::FileType.filetype(:crontab)
            end
        end

        self.filetype = self.defaulttype()

        # Override the default Puppet::Type method, because instances
        # also need to be deleted from the @instances hash
        def self.delete(child)
            if @instances.include?(child[:user])
                if @instances[child[:user]].include?(child)
                    @instances[child[:user]].delete(child)
                end
            end
            super
        end

        # Return the fields found in the cron tab.
        def self.fields
            return [:minute, :hour, :monthday, :month, :weekday, :command]
        end

        # Convert our hash to an object
        def self.hash2obj(hash)
            obj = nil
            namevar = self.namevar
            unless hash.include?(namevar) and hash[namevar]
                Puppet.info "Autogenerating name for %s" % hash[:command]
                hash[:name] = "autocron-%s" % hash.object_id
            end

            unless hash.include?(:command)
                raise Puppet::DevError, "No command for %s" % name
            end
            # if the cron already exists with that name...
            if obj = (self[hash[:name]] || match(hash))
                # Mark the cron job as present
                obj.is = [:ensure, :present]

                # Mark all of the values appropriately
                hash.each { |param, value|
                    if state = obj.state(param)
                        state.is = value
                    elsif val = obj[param]
                        obj[param] = val
                    else    
                        # There is a value on disk, but it should go away
                        obj.is = [param, value]
                        obj[param] = :absent
                    end
                }
            else
                # create a new cron job, since no existing one
                # seems to match
                obj = self.create(
                    :name => hash[namevar]
                )

                obj.is = [:ensure, :present]

                obj.notice "created"

                hash.delete(namevar)
                hash.each { |param, value|
                    obj.is = [param, value]
                }
            end

            instance(obj)
        end

        # Return the header placed at the top of each generated file, warning
        # users that modifying this file manually is probably a bad idea.
        def self.header
%{# HEADER This file was autogenerated at #{Time.now} by puppet.  While it
# HEADER can still be managed manually, it is definitely not recommended.
# HEADER Note particularly that the comments starting with 'Puppet Name' should
# HEADER not be deleted, as doing so could cause duplicate cron jobs.\n}
        end

        def self.instance(obj)
            user = obj[:user]
            unless @instances.include?(user)
                @instances[user] = []
            end

            @instances[user] << obj
        end

        def self.list
            # Look for cron jobs for each user
            Puppet::Type.type(:user).list_by_name.each { |user|
                self.retrieve(user, false)
            }

            self.collect { |c| c }
        end

        # See if we can match the hash against an existing cron job.
        def self.match(hash)
            self.find_all { |obj|
                obj[:user] == hash[:user] and obj.value(:command) == hash[:command][0]
            }.each do |obj|
                # we now have a cron job whose command exactly matches
                # let's see if the other fields match

                # First check the @special stuff
                if hash[:special]
                    next unless obj.value(:special) == hash[:special]
                end

                # Then the normal fields.
                matched = true
                fields().each do |field|
                    next if field == :command
                    if hash[field] and ! obj.value(field)
                        #Puppet.info "Cron is missing %s: %s and %s" %
                        #    [field, hash[field].inspect, obj.value(field).inspect]
                        matched = false
                        break
                    end

                    if ! hash[field] and obj.value(field)
                        #Puppet.info "Hash is missing %s: %s and %s" %
                        #    [field, obj.value(field).inspect, hash[field].inspect]
                        matched = false
                        break
                    end

                    # FIXME It'd be great if I could somehow reuse how the
                    # fields are turned into text, but....
                    next if (hash[field] == [:absent] and obj.value(field) == "*")
                    next if (hash[field].join(",") == obj.value(field))
                    #Puppet.info "Did not match %s: %s vs %s" %
                    #    [field, obj.value(field).inspect, hash[field].inspect]
                    matched = false 
                    break
                end
                next unless matched
                return obj
            end

            return false
        end

        # Parse a user's cron job into individual cron objects.
        #
        # Autogenerates names for any jobs that don't already have one; these
        # names will get written back to the file.
        #
        # This method also stores existing comments, and it stores all cron
        # jobs in order, mostly so that comments are retained in the order
        # they were written and in proximity to the same jobs.
        def self.parse(user, text)
            count = 0
            hash = {}

            envs = []
            text.chomp.split("\n").each { |line|
                case line
                when /^# Puppet Name: (.+)$/
                    hash[:name] = $1
                    next
                when /^#/:
                    # add other comments to the list as they are
                    @instances[user] << line 
                    next
                when /^\s*(\w+)\s*=\s*(.+)\s*$/:
                    # Match env settings.
                    if hash[:name]
                        envs << line
                    else
                        @instances[user] << line 
                    end
                    next
                when /^@(\w+)\s+(.+)/ # FreeBSD special cron crap
                    fields().each do |field|
                        next if field == :command
                        hash[field] = :absent
                    end
                    hash[:special] = $1
                    hash[:command] = $2
                else
                    if match = /^(\S+) (\S+) (\S+) (\S+) (\S+) (.+)$/.match(line)
                        fields().zip(match.captures).each { |param, value|
                            if value == "*"
                                hash[param] = [:absent]
                            else
                                if param == :command
                                    hash[param] = [value]
                                else
                                    # We always want the 'is' value to be an
                                    # array
                                    hash[param] = value.split(",")
                                end
                            end
                        }
                    else
                        # Don't fail on unmatched lines, just warn on them
                        # and skip them.
                        Puppet.warning "Could not match '%s'" % line
                        next
                    end
                end

                unless envs.empty?
                    # We have to dup here so that we don't remove the settings
                    # in @is on the object.
                    hash[:environment] = envs.dup
                end

                hash[:user] = user

                # Now convert our hash to an object.
                hash2obj(hash)

                hash = {}
                envs.clear
                count += 1
            }
        end

        # Retrieve a given user's cron job, using the @filetype's +retrieve+
        # method.  Returns nil if there was no cron job; else, returns the
        # number of cron instances found.
        def self.retrieve(user, checkuser = true)
            # First make sure the user exists, unless told not to
            if checkuser
                begin
                    Puppet::Util.uid(user)
                rescue ArgumentError
                    raise Puppet::Error,  "User %s not found" % user
                end
            end

            @tabs[user] ||= @filetype.new(user)
            text = @tabs[user].read
            if $? != 0
                # there is no cron file
                return nil
            else
                # Preemptively mark everything absent, so that retrieving it
                # can mark it present again.
                self.find_all { |obj|
                    obj[:user] == user
                }.each { |obj|
                    obj.is = [:ensure, :absent]
                }

                # Get rid of the old instances, so we don't get duplicates
                if @instances.include?(user)
                    @instances[user].clear
                else
                    @instances[user] = []
                end

                self.parse(user, text)
            end
        end

        # Remove a user's cron tab.
        def self.remove(user)
            @tabs[user] ||= @filetype.new(user)
            @tabs[user].remove
        end

        # Store the user's cron tab.  Collects the text of the new tab and
        # sends it to the +@filetype+ module's +write+ function.  Also adds
        # header, warning users not to modify the file directly.
        def self.store(user)
            unless @instances.include?(user) or @objects.find do |n,o|
                o[:user] == user
            end
                Puppet.notice "No cron instances for %s" % user
                return
            end

            @tabs[user] ||= @filetype.new(user)

            self.each do |inst|
                next unless inst[:user] == user
                unless (@instances[user] and @instances[user].include? inst)
                    @instances[user] ||= []
                    @instances[user] << inst
                end
            end
            @tabs[user].write(self.tab(user))
        end

        # Collect all Cron instances for a given user and convert them
        # into literal text.
        def self.tab(user)
            Puppet.info "Writing cron tab for %s" % user
            if @instances.include?(user)
                tab = @instances[user].reject { |obj|
                    if obj.is_a?(self) and obj.should(:ensure) == :absent
                        true
                    else
                        false
                    end
                }.collect { |obj|
                    if obj.is_a? self
                        obj.to_record
                    else
                        obj.to_s
                    end
                }.join("\n") + "\n"

                # Apparently Freebsd will "helpfully" add a new TZ line to every
                # single cron line, but not in all cases (e.g., it doesn't do it
                # on my machine.  This is my attempt to fix it so the TZ lines don't
                # multiply.
                if tab =~ /^TZ=.+$/
                    return tab.sub(/\n/, "\n" + self.header)
                else
                    return self.header() + tab
                end

            else
                Puppet.notice "No cron instances for %s" % user
            end
        end

        # Return the tab object itself.  Pretty much just used for testing.
        def self.tabobj(user)
            @tabs[user]
        end

        # Return the last time a given user's cron tab was loaded.  Could
        # be used for reducing writes, but currently is not.
        def self.loaded?(user)
            if @tabs.include?(user)
                return @loaded[user].loaded
            else
                return nil
            end
        end

        def create
            # nothing
            self.store
        end

        def destroy
            # nothing, since the 'Cron.tab' method just doesn't write out
            # crons whose 'ensure' states are set to 'absent'.
            self.store
        end

        def exists?
            @states.include?(:ensure) and @states[:ensure].is == :present
        end

        # Override the default Puppet::Type method because we need to call
        # the +@filetype+ retrieve method.
        def retrieve
            unless @parameters.include?(:user)
                self.fail "You must specify the cron user"
            end

            self.class.retrieve(self[:user])
            if withtab = self.class["testwithtab"]
                Puppet.info withtab.is(:ensure).inspect
            end
            self.eachstate { |st|
                st.retrieve
            }
            if withtab = self.class["testwithtab"]
                Puppet.info withtab.is(:ensure).inspect
            end
        end

        # Write the entire user's cron tab out.
        def store
            self.class.store(self[:user])
        end

        # Convert the current object a cron-style string.  Adds the cron name
        # as a comment above the cron job, in the form '# Puppet Name: <name>'.
        def to_record
            hash = {}

            # Collect all of the values that we have
            self.class.fields().each { |param|
                hash[param] = self.value(param)

                unless hash[param]
                    devfail "Got no value for %s" % param
                end
            }

            str = ""

            str = "# Puppet Name: %s\n" % self.name

            if @states.include?(:environment) and
                @states[:environment].should != :absent
                    envs = @states[:environment].should
                    unless envs.is_a? Array
                        envs = [envs]
                    end

                    envs.each do |line| str += (line + "\n") end
            end

            line = nil
            if special = self.value(:special)
                line = str + "@%s %s" %
                    [special, self.value(:command)]
            else
                line = str + self.class.fields.collect { |f|
                    if hash[f] and hash[f] != :absent
                        hash[f]
                    else
                        "*"
                    end
                }.join(" ")
            end

            return line
        end

        def value(name)
            name = name.intern if name.is_a? String
            ret = nil
            if @states.include?(name)
                ret = @states[name].should_to_s

                if ret.nil?
                    ret = @states[name].is_to_s
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
                    #ret = (self.class.validstate?(name).default || "*").to_s
                    ret = "*"
                end
            end

            ret
        end
    end
end

# $Id$
