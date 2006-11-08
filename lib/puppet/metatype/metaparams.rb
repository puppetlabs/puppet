require 'puppet'
require 'puppet/type'

class Puppet::Type
    # Add all of the meta parameters.
    #newmetaparam(:onerror) do
    #    desc "How to handle errors -- roll back innermost
    #        transaction, roll back entire transaction, ignore, etc.  Currently
    #        non-functional."
    #end

    newmetaparam(:noop) do
        desc "Boolean flag indicating whether work should actually
            be done.  *true*/**false**"
        munge do |noop|
            if noop == "true" or noop == true
                return true
            elsif noop == "false" or noop == false
                return false
            else
                self.fail("Invalid noop value '%s'" % noop)
            end
        end
    end

    newmetaparam(:schedule) do
        desc "On what schedule the object should be managed.  You must create a
            schedule object, and then reference the name of that object to use
            that for your schedule:

                schedule { daily:
                    period => daily,
                    range => \"2-4\"
                }

                exec { \"/usr/bin/apt-get update\":
                    schedule => daily
                }

            The creation of the schedule object does not need to appear in the
            configuration before objects that use it."

        munge do |name|
            if schedule = Puppet.type(:schedule)[name]
                return schedule
            else
                return name
            end
        end
    end

    newmetaparam(:check) do
        desc "States which should have their values retrieved
            but which should not actually be modified.  This is currently used
            internally, but will eventually be used for querying, so that you
            could specify that you wanted to check the install state of all
            packages, and then query the Puppet client daemon to get reports
            on all packages."

        munge do |args|
            # If they've specified all, collect all known states
            if args == :all
                args = @parent.class.states.collect do |state|
                    state.name
                end
            end

            unless args.is_a?(Array)
                args = [args]
            end

            unless defined? @parent
                self.devfail "No parent for %s, %s?" %
                    [self.class, self.name]
            end

            args.each { |state|
                unless state.is_a?(Symbol)
                    state = state.intern
                end
                next if @parent.statedefined?(state)

                stateklass = @parent.class.validstate?(state)

                unless stateklass
                    raise Puppet::Error, "%s is not a valid attribute for %s" %
                        [state, self.class.name]
                end
                next unless stateklass.checkable?

                @parent.newstate(state)
            }
        end
    end

    # For each object we require, subscribe to all events that it generates. We
    # might reduce the level of subscription eventually, but for now...
    newmetaparam(:require) do
        desc "One or more objects that this object depends on.
            This is used purely for guaranteeing that changes to required objects
            happen before the dependent object.  For instance:
            
                # Create the destination directory before you copy things down
                file { \"/usr/local/scripts\":
                    ensure => directory
                }

                file { \"/usr/local/scripts/myscript\":
                    source => \"puppet://server/module/myscript\",
                    mode => 755,
                    require => file[\"/usr/local/scripts\"]
                }

            Note that Puppet will autorequire everything that it can, and
            there are hooks in place so that it's easy for elements to add new
            ways to autorequire objects, so if you think Puppet could be
            smarter here, let us know.

            In fact, the above code was redundant -- Puppet will autorequire
            any parent directories that are being managed; it will
            automatically realize that the parent directory should be created
            before the script is pulled down.
            
            Currently, exec elements will autorequire their CWD (if it is
            specified) plus any fully qualified paths that appear in the
            command.   For instance, if you had an ``exec`` command that ran
            the ``myscript`` mentioned above, the above code that pulls the
            file down would be automatically listed as a requirement to the
            ``exec`` code, so that you would always be running againts the
            most recent version.
            "

        # Take whatever dependencies currently exist and add these.
        # Note that this probably doesn't behave correctly with unsubscribe.
        munge do |requires|
            # We need to be two arrays deep...
            unless requires.is_a?(Array)
                requires = [requires]
            end
            unless requires[0].is_a?(Array)
                requires = [requires]
            end
            if values = @parent[:require]
                requires = values + requires
            end
            requires
        end
    end

    # For each object we require, subscribe to all events that it generates.
    # We might reduce the level of subscription eventually, but for now...
    newmetaparam(:subscribe) do
        desc "One or more objects that this object depends on.  Changes in the
            subscribed to objects result in the dependent objects being
            refreshed (e.g., a service will get restarted).  For instance:
            
                class nagios {
                    file { \"/etc/nagios/nagios.conf\":
                        source => \"puppet://server/module/nagios.conf\",
                        alias => nagconf # just to make things easier for me
                    }
                    service { nagios:
                        running => true,
                        subscribe => file[nagconf]
                    }
                }
            "

        munge do |requires|
            if values = @parent[:subscribe]
                requires = values + requires
            end
            requires
        #    @parent.handledepends(requires, :ALL_EVENTS, :refresh)
        end
    end

    newmetaparam(:loglevel) do
        desc "Sets the level that information will be logged.
             The log levels have the biggest impact when logs are sent to
             syslog (which is currently the default)."
        defaultto :notice

        newvalues(*Puppet::Log.levels)
        newvalues(:verbose)

        munge do |loglevel|
            val = super(loglevel)
            if val == :verbose
                val = :info 
            end        
            val
        end
    end

    newmetaparam(:alias) do
        desc "Creates an alias for the object.  Puppet uses this internally when you
            provide a symbolic name:
            
                file { sshdconfig:
                    path => $operatingsystem ? {
                        solaris => \"/usr/local/etc/ssh/sshd_config\",
                        default => \"/etc/ssh/sshd_config\"
                    },
                    source => \"...\"
                }

                service { sshd:
                    subscribe => file[sshdconfig]
                }

            When you use this feature, the parser sets ``sshdconfig`` as the name,
            and the library sets that as an alias for the file so the dependency
            lookup for ``sshd`` works.  You can use this parameter yourself,
            but note that only the library can use these aliases; for instance,
            the following code will not work:

                file { \"/etc/ssh/sshd_config\":
                    owner => root,
                    group => root,
                    alias => sshdconfig
                }

                file { sshdconfig:
                    mode => 644
                }

            There's no way here for the Puppet parser to know that these two stanzas
            should be affecting the same file.

            See the [language tutorial][] for more information.

            [language tutorial]: languagetutorial.html
            
            "

        munge do |aliases|
            unless aliases.is_a?(Array)
                aliases = [aliases]
            end
            @parent.info "Adding aliases %s" % aliases.collect { |a|
                    a.inspect
            }.join(", ")
            aliases.each do |other|
                if obj = @parent.class[other]
                    unless obj == @parent
                        self.fail(
                            "%s can not create alias %s: object already exists" %
                            [@parent.title, other]
                        )
                    end
                    next
                end
                @parent.class.alias(other, @parent)
            end
        end
    end

    newmetaparam(:tag) do
        desc "Add the specified tags to the associated element.  While all elements
            are automatically tagged with as much information as possible
            (e.g., each class and component containing the element), it can
            be useful to add your own tags to a given element.

            Tags are currently useful for things like applying a subset of a
            host's configuration:
                
                puppetd --test --tag mytag

            This way, when you're testing a configuration you can run just the
            portion you're testing."

        munge do |tags|
            tags = [tags] unless tags.is_a? Array

            tags.each do |tag|
                @parent.tag(tag)
            end
        end
    end

    newmetaparam(:notify) do
        desc %{This parameter is the opposite of **subscribe** -- it sends events
            to the specified object:

                file { "/etc/sshd_config":
                    source => "....",
                    notify => service[sshd]
                }

                service { sshd:
                    ensure => running
                }
            
            This will restart the sshd service if the sshd config file changes.}


        # Take whatever dependencies currently exist and add these.
        munge do |notifies|
            # We need to be two arrays deep...
            unless notifies.is_a?(Array)
                notifies = [notifies]
            end
            unless notifies[0].is_a?(Array)
                notifies = [notifies]
            end
            if values = @parent[:notify]
                notifies = values + notifies
            end
            notifies
        end
        
    end

    newmetaparam(:before) do
        desc %{This parameter is the opposite of **require** -- it guarantees
            that the specified object is applied later than the specifying
            object:

                file { "/var/nagios/configuration":
                    source  => "...",
                    recurse => true,
                    before => exec["nagios-rebuid"]
                }

                exec { "nagios-rebuild":
                    command => "/usr/bin/make",
                    cwd => "/var/nagios/configuration"
                }
            
            This will make sure all of the files are up to date before the
            make command is run.}

        # Take whatever dependencies currently exist and add these.
        munge do |notifies|
            # We need to be two arrays deep...
            unless notifies.is_a?(Array)
                notifies = [notifies]
            end
            unless notifies[0].is_a?(Array)
                notifies = [notifies]
            end
            if values = @parent[:notify]
                notifies = values + notifies
            end
            notifies
        end
        
    end
end # Puppet::Type

# $Id$
