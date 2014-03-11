Puppet::Type.type(:service).provide :base, :parent => :service do
  desc "The simplest form of Unix service support.

  You have to specify enough about your service for this to work; the
  minimum you can specify is a binary for starting the process, and this
  same binary will be searched for in the process table to stop the
  service.  As with `init`-style services, it is preferable to specify start,
  stop, and status commands.

  "

  commands :kill => "kill"

  # Get the process ID for a running process. Requires the 'pattern'
  # parameter.
  def getpid
    @resource.fail "Either stop/status commands or a pattern must be specified" unless @resource[:pattern]
    ps = Facter["ps"].value
    @resource.fail "You must upgrade Facter to a version that includes 'ps'" unless ps and ps != ""
    regex = Regexp.new(@resource[:pattern])
    self.debug "Executing '#{ps}'"
    IO.popen(ps) { |table|
      table.each_line { |line|
        if regex.match(line)
          self.debug "Process matched: #{line}"
          ary = line.sub(/^\s+/, '').split(/\s+/)
          return ary[1]
        end
      }
    }

    nil
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
      if $CHILD_STATUS.exitstatus == 0
        return :running
      else
        return :stopped
      end
    elsif pid = self.getpid
      self.debug "PID is #{pid}"
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
        self.info "#{self.name} is not running"
        return false
      end
      begin
        output = kill pid
      rescue Puppet::ExecutionFailure
        @resource.fail Puppet::Error, "Could not kill #{self.name}, PID #{pid}: #{output}", $!
      end
      return true
    end
  end

  # There is no default command, which causes other methods to be used
  def stopcmd
  end
end

