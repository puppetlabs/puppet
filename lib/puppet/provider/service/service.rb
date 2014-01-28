Puppet::Type.type(:service).provide :service do
  desc "The simplest form of service support."

  def self.instances
    []
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

  # A simple wrapper so execution failures are a bit more informative.
  def texecute(type, command, fof = true, squelch = false, combine = true)
    begin
      execute(command, :failonfail => fof, :override_locale => false, :squelch => squelch, :combine => combine)
    rescue Puppet::ExecutionFailure => detail
      @resource.fail Puppet::Error, "Could not #{type} #{@resource.ref}: #{detail}", detail
    end
    nil
  end

  # Use either a specified command or the default for our provider.
  def ucommand(type, fof = true)
    if c = @resource[type]
      cmd = [c]
    else
      cmd = [send("#{type}cmd")].flatten
    end
    texecute(type, cmd, fof)
  end
end

