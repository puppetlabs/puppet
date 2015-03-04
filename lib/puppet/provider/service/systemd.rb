# Manage systemd services using /bin/systemctl

Puppet::Type.type(:service).provide :systemd, :parent => :base do
  desc "Manages `systemd` services using `systemctl`."

  commands :systemctl => "systemctl"

  defaultfor :osfamily => [:archlinux]
  defaultfor :osfamily => :redhat, :operatingsystemmajrelease => "7"
  defaultfor :osfamily => :redhat, :operatingsystem => :fedora, :operatingsystemmajrelease => ["17", "18", "19", "20", "21"]
  defaultfor :osfamily => :suse, :operatingsystemmajrelease => ["12", "13"]

  def self.instances
    i = []
    output = systemctl('list-unit-files', '--type', 'service', '--full', '--all',  '--no-pager')
    output.scan(/^(\S+)\s+(disabled|enabled|masked)\s*$/i).each do |m|
      i << new(:name => m[0])
    end
    return i
  rescue Puppet::ExecutionFailure
    return []
  end

  def disable
    output = systemctl(:disable, @resource[:name])
  rescue Puppet::ExecutionFailure
    raise Puppet::Error, "Could not disable #{self.name}: #{output}", $!.backtrace
  end

  def enabled?
    begin
      systemctl_info = systemctl(
         'show',
         @resource[:name],
         '--property', 'LoadState',
         '--property', 'UnitFileState',
         '--no-pager'
      )

      svc_info = Hash.new
      systemctl_info.split.map{|svc|
        entry_pair = svc.split('=')
        svc_info[entry_pair.first.to_sym] = entry_pair.last
      }

      # The masked state is equivalent to the disabled state in terms of
      # comparison so we only care to check if it is masked if we want to keep
      # it masked.
      #
      # We only return :mask if we're trying to mask the service. This prevents
      # flapping when simply trying to disable a masked service.
      return :mask if (@resource[:enable] == :mask) && (svc_info[:LoadState] == 'masked')
      return :true if svc_info[:UnitFileState] == 'enabled'
    rescue Puppet::ExecutionFailure
      # Don't worry about this failing, just return :false if it does.
    end

    return :false
  end

  def status
    begin
      systemctl("is-active", @resource[:name])
    rescue Puppet::ExecutionFailure
      return :stopped
    end
    return :running
  end

  def enable
    output = systemctl("unmask", @resource[:name])
    output = systemctl("enable", @resource[:name])
  rescue Puppet::ExecutionFailure
    raise Puppet::Error, "Could not enable #{self.name}: #{output}", $!.backtrace
  end

  def mask
    begin
      output = systemctl("mask", @resource[:name])
    rescue Puppet::ExecutionFailure
      raise Puppet::Error, "Could not mask #{self.name}: #{output}", $!.backtrace
    end
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

