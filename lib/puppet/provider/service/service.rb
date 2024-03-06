# frozen_string_literal: true

Puppet::Type.type(:service).provide :service do
  desc "The simplest form of service support."

  def self.instances
    []
  end

  # How to restart the process.
  def restart
    if @resource[:restart] or restartcmd
      service_command(:restart)
      nil
    else
      stop
      start
    end
  end

  # There is no default command, which causes other methods to be used
  def restartcmd
  end

  # @deprecated because the exit status is not returned, use service_execute instead
  def texecute(type, command, fof = true, squelch = false, combine = true)
    begin
      execute(command, :failonfail => fof, :override_locale => false, :squelch => squelch, :combine => combine)
    rescue Puppet::ExecutionFailure => detail
      @resource.fail Puppet::Error, "Could not #{type} #{@resource.ref}: #{detail}", detail
    end
    nil
  end

  # @deprecated because the exitstatus is not returned, use service_command instead
  def ucommand(type, fof = true)
    c = @resource[type]
    if c
      cmd = [c]
    else
      cmd = [send("#{type}cmd")].flatten
    end
    texecute(type, cmd, fof)
  end

  # Execute a command, failing the resource if the command fails.
  #
  # @return [Puppet::Util::Execution::ProcessOutput]
  def service_execute(type, command, fof = true, squelch = false, combine = true)
    execute(command, :failonfail => fof, :override_locale => false, :squelch => squelch, :combine => combine)
  rescue Puppet::ExecutionFailure => detail
    @resource.fail Puppet::Error, "Could not #{type} #{@resource.ref}: #{detail}", detail
  end

  # Use either a specified command or the default for our provider.
  #
  # @return [Puppet::Util::Execution::ProcessOutput]
  def service_command(type, fof = true)
    c = @resource[type]
    if c
      cmd = [c]
    else
      cmd = [send("#{type}cmd")].flatten
    end
    service_execute(type, cmd, fof)
  end
end
