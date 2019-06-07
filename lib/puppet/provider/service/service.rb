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
    # Set the process priority to 0 (or normal in Windows) so that services
    # which are started as children of puppet will start with normal priority,
    # rather than the priority of the puppet process itself.
    begin
      opts = {
        :combine => combine,
        :failonfail => fof,
        :override_locale => false,
        :priority => :normal,
        :squelch => squelch,
      }
      execute(command, opts)
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

