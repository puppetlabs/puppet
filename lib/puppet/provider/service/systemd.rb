# Manage systemd services using systemctl

Puppet::Type.type(:service).provide :systemd, :parent => :base do
  desc "Manages `systemd` services using `systemctl`."

  commands :systemctl => "systemctl"

  if Facter.value(:osfamily).downcase == 'debian'
    # With multiple init systems on Debian, it is possible to have
    # pieces of systemd around (e.g. systemctl) but not really be
    # using systemd.  We do not do this on other platforms as it can
    # cause issues when running in a chroot without /run mounted
    # (PUP-5577)
    confine :exists => "/run/systemd/system"
  end

  defaultfor :osfamily => [:archlinux]
  defaultfor :osfamily => :redhat, :operatingsystemmajrelease => "7"
  defaultfor :osfamily => :redhat, :operatingsystem => :fedora
  defaultfor :osfamily => :suse
  defaultfor :operatingsystem => :debian, :operatingsystemmajrelease => "8"
  defaultfor :operatingsystem => :ubuntu, :operatingsystemmajrelease => ["15.04","15.10","16.04"]

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

  def get_start_link_count
    # Start links don't include '.service'. Just search for the service name.
    if @resource[:name].match(/\.service/)
      link_name = @resource[:name].split('.')[0]
    else
      link_name = @resource[:name]
    end

    Dir.glob("/etc/rc*.d/S??#{link_name}").length
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
      systemctl_info.split.each do |svc|
        entry_pair = svc.split('=')
        svc_info[entry_pair.first.to_sym] = entry_pair.last
      end

      # The masked state is equivalent to the disabled state in terms of
      # comparison so we only care to check if it is masked if we want to keep
      # it masked.
      #
      # We only return :mask if we're trying to mask the service. This prevents
      # flapping when simply trying to disable a masked service.
      return :mask if (@resource[:enable] == :mask) && (svc_info[:LoadState] == 'masked')
      return :true if svc_info[:UnitFileState] == 'enabled'
      if Facter.value(:osfamily).downcase == 'debian'
        ret = debian_enabled?(svc_info)
        return ret if ret
      end
    rescue Puppet::ExecutionFailure
      # The execution of the systemd command can fail for quite a few reasons.
      # In all of these cases, the failure of the query indicates that the
      # service is disabled and therefore we simply return :false.
    end

    return :false
  end

  # This method is required for Debian systems due to the way the SysVInit-Systemd
  # compatibility layer works. When we are trying to manage a service which does not
  # have a Systemd unit file, we need to go through the old init script to determine
  # whether it is enabled or not. See PUP-5016 for more details.
  #
  def debian_enabled?(svc_info)
    # If UnitFileState == UnitFileState then we query the older way.
    if svc_info[:UnitFileState] == 'UnitFileState'
      system("/usr/sbin/invoke-rc.d", "--quiet", "--query", @resource[:name], "start")
      if [104, 106].include?($CHILD_STATUS.exitstatus)
        return :true
      elsif [101, 105].include?($CHILD_STATUS.exitstatus)
        # 101 is action not allowed, which means we have to do the check manually.
        # 105 is unknown, which generally means the iniscript does not support query
        # The debian policy states that the initscript should support methods of query
        # For those that do not, peform the checks manually
        # http://www.debian.org/doc/debian-policy/ch-opersys.html
        if get_start_link_count >= 4
          return :true
        else
          return :false
        end
      else
        return :false
      end
    end
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
    self.unmask
    output = systemctl("enable", @resource[:name])
  rescue Puppet::ExecutionFailure
    raise Puppet::Error, "Could not enable #{self.name}: #{output}", $!.backtrace
  end

  def mask
    self.disable
    begin
      output = systemctl("mask", @resource[:name])
    rescue Puppet::ExecutionFailure
      raise Puppet::Error, "Could not mask #{self.name}: #{output}", $!.backtrace
    end
  end

  def unmask
    begin
      output = systemctl("unmask", @resource[:name])
    rescue Puppet::ExecutionFailure
      raise Puppet::Error, "Could not unmask #{self.name}: #{output}", $!.backtrace
    end
  end

  def restartcmd
    [command(:systemctl), "restart", @resource[:name]]
  end

  def startcmd
    self.unmask
    [command(:systemctl), "start", @resource[:name]]
  end

  def stopcmd
    [command(:systemctl), "stop", @resource[:name]]
  end
end

