# Manage systemd services using /bin/systemctl

Puppet::Type.type(:service).provide :systemd, :parent => :base do
  desc "Manage systemd services using /bin/systemctl"

  commands :systemctl => "/bin/systemctl"

  #defaultfor :operatingsystem => [:redhat, :fedora, :suse, :centos, :sles, :oel, :ovm]

  def self.instances
    i = []
    output = `systemctl list-units --full --all --no-pager`
    output.scan(/^(\S+)\s+(loaded|error)\s+(active|inactive)\s+(active|waiting|running|plugged|mounted|dead|exited|listening|elapsed)\s*?(\S.*?)?$/i).each do |m|
      i << m[0]
    end
    return i
  rescue Puppet::ExecutionFailure
    return []
  end

  def disable
    output = systemctl(:disable, @resource[:name])
  rescue Puppet::ExecutionFailure
    raise Puppet::Error, "Could not disable #{self.name}: #{output}"
  end

  def enabled?
    begin
      systemctl("is-enabled", @resource[:name])
    rescue Puppet::ExecutionFailure
      return :false
    end

    :true
  end

  def status
    begin
      output = systemctl("is-active", @resource[:name])
    rescue Puppet::ExecutionFailure
      return :stopped
    end
    return :running
  end

  def enable
    output = systemctl("enable", @resource[:name])
  rescue Puppet::ExecutionFailure
    raise Puppet::Error, "Could not enable #{self.name}: #{output}"
  end

  def restartcmd
    [command(:systemctl), "restart", @resource[:name]]
  end

  def startcmd
    [command(:systemctl), "start", @resource[:name]]
  end

  def stopcmd
    [command(:systemctl), "stop", @resource[:name]]
  end
end

