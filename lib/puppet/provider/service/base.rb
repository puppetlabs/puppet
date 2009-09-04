Puppet::Type.type(:service).provide :base do
    desc "The simplest form of service support.

    You have to specify enough about your service for this to work; the
    minimum you can specify is a binary for starting the process, and this
    same binary will be searched for in the process table to stop the
    service.  It is preferable to specify start, stop, and status commands,
    akin to how you would do so using ``init``.

    "

    commands :kill => "kill"

    def self.instances
        []
    end

    # Get the process ID for a running process. Requires the 'pattern'
    # parameter.
    def getpid
        unless @resource[:pattern]
            @resource.fail "Either stop/status commands or a pattern must be specified"
        end
        ps = Facter["ps"].value
        unless ps and ps != ""
            @resource.fail "You must upgrade Facter to a version that includes 'ps'"
        end
        regex = Regexp.new(@resource[:pattern])
        self.debug "Executing '#{ps}'"
        IO.popen(ps) { |table|
            table.each { |line|
                if regex.match(line)
                    ary = line.sub(/^\s+/, '').split(/\s+/)
                    return ary[1]
                end
            }
        }

        return nil
    end

    # How to restart the process.
    def restart
        if @resource[:restart] or restartcmd
            ucommand(:restart)
        else
            self.stop
            self.start
        end
    end

    # There is no default command, which causes other methods to be used  
    def restartcmd
    end

    # Check if the process is running.  Prefer the 'status' parameter,
    # then 'statuscmd' method, then look in the process table.  We give
    # the object the option to not return a status command, which might
    # happen if, for instance, it has an init script (and thus responds to
    # 'statuscmd') but does not have 'hasstatus' enabled.
    def status
        if @resource[:status] or statuscmd
            # Don't fail when the exit status is not 0.
            ucommand(:status, false)

            # Expicitly calling exitstatus to facilitate testing
            if $?.exitstatus == 0
                return :running
            else
                return :stopped
            end
        elsif pid = self.getpid
            self.debug "PID is %s" % pid
            return :running
        else
            return :stopped
        end
    end

    # There is no default command, which causes other methods to be used  
    def statuscmd
    end
    
    # Run the 'start' parameter command, or the specified 'startcmd'.
    def start
        ucommand(:start)
    end

    # The command used to start.  Generated if the 'binary' argument
    # is passed.
    def startcmd
        if @resource[:binary]
            return @resource[:binary]
        else
            raise Puppet::Error,
                "Services must specify a start command or a binary"
        end
    end

    # Stop the service.  If a 'stop' parameter is specified, it
    # takes precedence; otherwise checks if the object responds to
    # a 'stopcmd' method, and if so runs that; otherwise, looks
    # for the process in the process table.
    # This method will generally not be overridden by submodules.
    def stop
        if @resource[:stop] or stopcmd
            ucommand(:stop)
        else
            pid = getpid
            unless pid
                self.info "%s is not running" % self.name
                return false
            end
            begin
                output = kill pid
            rescue Puppet::ExecutionFailure => detail
                @resource.fail "Could not kill %s, PID %s: %s" %
                        [self.name, pid, output]
            end
            return true
        end
    end
    
    # There is no default command, which causes other methods to be used  
    def stopcmd
    end

    # A simple wrapper so execution failures are a bit more informative.
    def texecute(type, command, fof = true)
        begin
            # #565: Services generally produce no output, so squelch them.
            execute(command, :failonfail => fof, :squelch => true)
        rescue Puppet::ExecutionFailure => detail
            @resource.fail "Could not %s %s: %s" % [type, @resource.ref, detail]
        end
        return nil
    end

    # Use either a specified command or the default for our provider.
    def ucommand(type, fof = true)
        if c = @resource[type]
            cmd = [c]
        else
            cmd = self.send("%scmd" % type)
        end
        return texecute(type, cmd, fof)
    end
end

