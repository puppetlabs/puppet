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
  def texecute(type, command, fof = true)
    begin
      # #565: Services generally produce no output, so squelch them.
      execute(command, :failonfail => fof, :override_locale => false, :squelch => true)
    rescue Puppet::ExecutionFailure => detail
      @resource.fail "Could not #{type} #{@resource.ref}: #{detail}"
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

