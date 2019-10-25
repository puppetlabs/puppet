# Manage systemd services using systemctl

require 'puppet/file_system'

Puppet::Type.type(:service).provide :systemd, :parent => :base do
  desc "Manages `systemd` services using `systemctl`.

  Because `systemd` defaults to assuming the `.service` unit type, the suffix
  may be omitted.  Other unit types (such as `.path`) may be managed by
  providing the proper suffix."

  commands :systemctl => "systemctl"

  confine :true => Puppet::FileSystem.exist?('/proc/1/comm') && Puppet::FileSystem.read('/proc/1/comm').include?('systemd')

  defaultfor :osfamily => [:archlinux]
  defaultfor :osfamily => :redhat, :operatingsystemmajrelease => ["7", "8"]
  defaultfor :osfamily => :redhat, :operatingsystem => :fedora
  defaultfor :osfamily => :suse
  defaultfor :osfamily => :coreos
  defaultfor :operatingsystem => :amazon, :operatingsystemmajrelease => ["2"]
  defaultfor :operatingsystem => :debian
  notdefaultfor :operatingsystem => :debian, :operatingsystemmajrelease => ["5", "6", "7"] # These are using the "debian" method
  defaultfor :operatingsystem => :LinuxMint
  notdefaultfor :operatingsystem => :LinuxMint, :operatingsystemmajrelease => ["10", "11", "12", "13", "14", "15", "16", "17"] # These are using upstart
  defaultfor :operatingsystem => :ubuntu
  notdefaultfor :operatingsystem => :ubuntu, :operatingsystemmajrelease => ["10.04", "12.04", "14.04", "14.10"] # These are using upstart
  defaultfor :operatingsystem => :cumuluslinux, :operatingsystemmajrelease => ["3"]

  def self.instances
    i = []
    output = systemctl('list-unit-files', '--type', 'service', '--full', '--all',  '--no-pager')
    output.scan(/^(\S+)\s+(disabled|enabled|masked|indirect)\s*$/i).each do |m|
      i << new(:name => m[0])
    end
    return i
  rescue Puppet::ExecutionFailure
    return []
  end

  # This helper ensures that the enable state cache is always reset
  # after a systemctl enable operation. A particular service state is not guaranteed
  # after such an operation, so the cache must be emptied to prevent inconsistencies
  # in the provider's believed state of the service and the actual state.
  # @param action [String,Symbol] One of 'enable', 'disable', 'mask' or 'unmask'
  def systemctl_change_enable(action)
    output = systemctl(action, '--', @resource[:name])
  rescue
    raise Puppet::Error, "Could not #{action} #{self.name}: #{output}", $!.backtrace
  ensure
    @cached_enabled = nil
  end

  def disable
    systemctl_change_enable(:disable)
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

  def cached_enabled?
    return @cached_enabled if @cached_enabled
    cmd = [command(:systemctl), 'is-enabled', '--', @resource[:name]]
    @cached_enabled = execute(cmd, :failonfail => false).strip
  end

  def enabled?
    output = cached_enabled?
    code = $CHILD_STATUS.exitstatus

    # The masked state is equivalent to the disabled state in terms of
    # comparison so we only care to check if it is masked if we want to keep
    # it masked.
    #
    # We only return :mask if we're trying to mask the service. This prevents
    # flapping when simply trying to disable a masked service.
    return :mask if (@resource[:enable] == :mask) && (output == 'masked')

    # The indirect state indicates that the unit is not enabled.
    return :false if output == 'indirect'
    return :true if (code == 0)
    if (output.empty?) && (code > 0) && (Facter.value(:osfamily).downcase == 'debian')
      ret = debian_enabled?
      return ret if ret
    end

    return :false
  end

  # This method is required for Debian systems due to the way the SysVInit-Systemd
  # compatibility layer works. When we are trying to manage a service which does not
  # have a Systemd unit file, we need to go through the old init script to determine
  # whether it is enabled or not. See PUP-5016 for more details.
  #
  def debian_enabled?
    system("/usr/sbin/invoke-rc.d", "--quiet", "--query", @resource[:name], "start")
    if [104, 106].include?($CHILD_STATUS.exitstatus)
      return :true
    elsif [101, 105].include?($CHILD_STATUS.exitstatus)
      # 101 is action not allowed, which means we have to do the check manually.
      # 105 is unknown, which generally means the initscript does not support query
      # The debian policy states that the initscript should support methods of query
      # For those that do not, perform the checks manually
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

  # Define the daemon_reload? function to check if the unit is requiring to trigger a "systemctl daemon-reload"
  # If the unit file is flagged with NeedDaemonReload=yes, then a systemd daemon-reload will be run.
  # If multiple unit files have been updated, the first one flagged will trigger the daemon-reload for all of them.
  # The others will be then flagged with NeedDaemonReload=no. So the command will run only once in a puppet run.
  # This function is called only on start & restart unit options.
  # Reference: (PUP-3483) Systemd provider doesn't scan for changed units
  def daemon_reload?
    cmd = [command(:systemctl), 'show', '--', @resource[:name], '--property=NeedDaemonReload']
    daemon_reload = execute(cmd, :failonfail => false).strip.split('=').last
    if daemon_reload == 'yes'
      daemon_reload_cmd = [command(:systemctl), '--', 'daemon-reload']
      execute(daemon_reload_cmd, :failonfail => false)
    end
  end

  def enable
    self.unmask
    systemctl_change_enable(:enable)
  end

  def mask
    self.disable
    systemctl_change_enable(:mask)
  end

  def unmask
    systemctl_change_enable(:unmask)
  end

  def restartcmd
    [command(:systemctl), "restart", '--', @resource[:name]]
  end

  def startcmd
    self.unmask
    [command(:systemctl), "start", '--', @resource[:name]]
  end

  def stopcmd
    [command(:systemctl), "stop", '--', @resource[:name]]
  end

  def statuscmd
    [command(:systemctl), "is-active", '--', @resource[:name]]
  end

  def restart
    begin
      daemon_reload?
      super
    rescue Puppet::Error => e
      raise Puppet::Error.new(prepare_error_message(@resource[:name], 'restart', e))
    end
  end

  def start
    begin
      daemon_reload?
      super
    rescue Puppet::Error => e
      raise Puppet::Error.new(prepare_error_message(@resource[:name], 'start', e))
    end
  end

  def stop
    begin
      super
    rescue Puppet::Error => e
      raise Puppet::Error.new(prepare_error_message(@resource[:name], 'stop', e))
    end
  end

  def prepare_error_message(name, action, exception)
    error_return = "Systemd #{action} for #{name} failed!\n"
    journalctl_command = "journalctl -n 50 --since '5 minutes ago' -u #{name} --no-pager"
    Puppet.debug("Running journalctl command to get logs for systemd #{action} failure: #{journalctl_command}")
    journalctl_output = execute(journalctl_command)
    error_return << "journalctl log for #{name}:\n#{journalctl_output}"
  end
end

