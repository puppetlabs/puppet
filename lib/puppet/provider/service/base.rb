Puppet::Type.type(:service).provide :base, :parent => :service do
  desc "The simplest form of Unix service support.

  You have to specify enough about your service for this to work; the
  minimum you can specify is a binary for starting the process, and this
  same binary will be searched for in the process table to stop the
  service.  As with `init`-style services, it is preferable to specify start,
  stop, and status commands.

  "

  commands :kill => "kill"

  # get the proper 'ps' invocation for the platform
  # ported from the facter 2.x implementation, since facter 3.x
  # is dropping the fact (for which this was the only use)
  def getps
    case Facter.value(:operatingsystem)
    when 'OpenWrt'
      'ps www'
    when 'FreeBSD', 'NetBSD', 'OpenBSD', 'Darwin', 'DragonFly'
      'ps auxwww'
    else
      'ps -ef'
    end
  end
  private :getps

  # Get the process ID for a running process. Requires the 'pattern'
  # parameter.
  def getpid
    @resource.fail "Either stop/status commands or a pattern must be specified" unless @resource[:pattern]
    regex = Regexp.new(@resource[:pattern])
    ps = getps

    self.debug "Executing '#{ps}'"
    table = Puppet::Util::Execution.execute(ps)

    # The output of the PS command can be a mashup of several different
    # encodings depending on which processes are running and what
    # arbitrary data has been used to set their name in the process table.
    #
    # First, try a polite conversion to in order to match the UTF-8 encoding
    # of our regular expression.
    table = Puppet::Util::CharacterEncoding.convert_to_utf_8(table)
    # If that fails, force to UTF-8 and then scrub as most uses are scanning
    # for ACII-compatible program names.
    table.force_encoding(Encoding::UTF_8) unless table.encoding == Encoding::UTF_8
    table = Puppet::Util::CharacterEncoding.scrub(table) unless table.valid_encoding?

    table.each_line { |line|
      if regex.match(line)
        self.debug "Process matched: #{line}"
        ary = line.sub(/^[[:space:]]+/u, '').split(/[[:space:]]+/u)
        return ary[1]
      end
    }

    nil
  end
  private :getpid

  # Check if the process is running.  Prefer the 'status' parameter,
  # then 'statuscmd' method, then look in the process table.  We give
  # the object the option to not return a status command, which might
  # happen if, for instance, it has an init script (and thus responds to
  # 'statuscmd') but does not have 'hasstatus' enabled.
  def status
    if @resource[:status] or statuscmd
      # Don't fail when the exit status is not 0.
      ucommand(:status, false)

      # Explicitly calling exitstatus to facilitate testing
      if $CHILD_STATUS.exitstatus == 0
        return :running
      else
        return :stopped
      end
    elsif pid = getpid
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
        self.info _("%{name} is not running") % { name: self.name }
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

