# Manage Red Hat services.  Start/stop uses /sbin/service and enable/disable uses chkconfig

Puppet::Type.type(:service).provide :redhat, :parent => :init, :source => :init do
  desc "Red Hat's (and probably many others') form of `init`-style service
    management. Uses `chkconfig` for service enabling and disabling.

  "

  commands :chkconfig => "/sbin/chkconfig", :service => "/sbin/service"

  defaultfor :osfamily => [:redhat, :suse]

  # Remove the symlinks
  def disable
    # The off method operates on run levels 2,3,4 and 5 by default We ensure
    # all run levels are turned off because the reset method may turn on the
    # service in run levels 0, 1 and/or 6
    output = chkconfig("--level", "0123456", @resource[:name], :off)
  rescue Puppet::ExecutionFailure
    raise Puppet::Error, "Could not disable #{self.name}: #{output}"
  end

  def enabled?
    # Checkconfig always returns 0 on SuSE unless the --check flag is used.
    args = (Facter.value(:osfamily) == 'Suse' ? ['--check'] : [])

    begin
      chkconfig(@resource[:name], *args)
    rescue Puppet::ExecutionFailure
      return :false
    end

    :true
  end

  # Don't support them specifying runlevels; always use the runlevels
  # in the init scripts.
  def enable
      chkconfig(@resource[:name], :on)
  rescue Puppet::ExecutionFailure => detail
    raise Puppet::Error, "Could not enable #{self.name}: #{detail}"
  end

  def initscript
    raise Puppet::Error, "Do not directly call the init script for '#{@resource[:name]}'; use 'service' instead"
  end

  # use hasstatus=>true when its set for the provider.
  def statuscmd
    ((@resource.provider.get(:hasstatus) == true) || (@resource[:hasstatus] == :true)) && [command(:service), @resource[:name], "status"]
  end

  def restartcmd
    (@resource[:hasrestart] == :true) && [command(:service), @resource[:name], "restart"]
  end

  def startcmd
    [command(:service), @resource[:name], "start"]
  end

  def stopcmd
    [command(:service), @resource[:name], "stop"]
  end
end
