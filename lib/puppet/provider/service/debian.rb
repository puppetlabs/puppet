# frozen_string_literal: true

# Manage debian services.  Start/stop is the same as InitSvc, but enable/disable
# is special.
Puppet::Type.type(:service).provide :debian, :parent => :init do
  desc <<-EOT
    Debian's form of `init`-style management.

    The only differences from `init` are support for enabling and disabling
    services via `update-rc.d` and the ability to determine enabled status via
    `invoke-rc.d`.

  EOT

  commands :update_rc => "/usr/sbin/update-rc.d"
  # note this isn't being used as a command until
  # https://projects.puppetlabs.com/issues/2538
  # is resolved.
  commands :invoke_rc => "/usr/sbin/invoke-rc.d"
  commands :service => "/usr/sbin/service"

  confine :false => Puppet::FileSystem.exist?('/proc/1/comm') && Puppet::FileSystem.read('/proc/1/comm').include?('systemd')

  defaultfor 'os.name' => :cumuluslinux, 'os.release.major' => %w[1 2]
  defaultfor 'os.name' => :debian, 'os.release.major' => %w[5 6 7]
  defaultfor 'os.name' => :devuan

  # Remove the symlinks
  def disable
    if `dpkg --compare-versions $(dpkg-query -W --showformat '${Version}' sysv-rc) ge 2.88 ; echo $?`.to_i == 0
      update_rc @resource[:name], "disable"
    else
      update_rc "-f", @resource[:name], "remove"
      update_rc @resource[:name], "stop", "00", "1", "2", "3", "4", "5", "6", "."
    end
  end

  def enabled?
    status = execute(["/usr/sbin/invoke-rc.d", "--quiet", "--query", @resource[:name], "start"], :failonfail => false)

    # 104 is the exit status when you query start an enabled service.
    # 106 is the exit status when the policy layer supplies a fallback action
    # See x-man-page://invoke-rc.d
    if [104, 106].include?(status.exitstatus)
      :true
    elsif [101, 105].include?(status.exitstatus)
      # 101 is action not allowed, which means we have to do the check manually.
      # 105 is unknown, which generally means the initscript does not support query
      # The debian policy states that the initscript should support methods of query
      # For those that do not, perform the checks manually
      # http://www.debian.org/doc/debian-policy/ch-opersys.html
      if get_start_link_count >= 4
        :true
      else
        :false
      end
    else
      :false
    end
  end

  def get_start_link_count
    Dir.glob("/etc/rc*.d/S??#{@resource[:name]}").length
  end

  def enable
    update_rc "-f", @resource[:name], "remove"
    update_rc @resource[:name], "defaults"
  end

  def statuscmd
    # /usr/sbin/service provides an abstraction layer which is able to query services
    # independent of the init system used.
    # See https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=775795
    (@resource[:hasstatus] == :true) && [command(:service), @resource[:name], "status"]
  end
end
